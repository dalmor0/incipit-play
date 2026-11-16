// Incipit Play · clipes. Ver cliprecorder.h.
#include "cliprecorder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrl>
#include <QImage>
#include <QTimer>
#include <QMediaPlayer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QWebSocket>
#include <QtConcurrent/QtConcurrentRun>
#include <QRegularExpression>
#include <functional>
#include <memory>
#include <vector>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/channel_layout.h>
}

#ifdef Q_OS_WIN
#include <windows.h>
#endif

static const int HOTKEY_ID = 0x1C1B;

ClipRecorder *ClipRecorder::instance()
{
	static ClipRecorder *r = nullptr;
	if(!r)
		r = new ClipRecorder(QCoreApplication::instance());
	return r;
}

ClipRecorder::ClipRecorder(QObject *parent) : QObject(parent)
{
	clock.start();
	clips_dir = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + QStringLiteral("/Incipit Play");
	QCoreApplication::instance()->installNativeEventFilter(this);
}

// ---------------------------------------------------------------- análise dos pacotes

// quadro-chave: H.264 NAL 5 (IDR); HEVC NAL 16 a 21 (IRAP). Só olha o começo do pacote, onde ficam os
// conjuntos de parâmetros e a primeira fatia.
static bool IsKeyframe(const uint8_t *b, size_t n, bool hevc)
{
	const size_t lim = n < 1024 ? n : 1024;
	for(size_t i = 0; i + 3 < lim; i++)
	{
		if(b[i] != 0 || b[i + 1] != 0)
			continue;
		size_t h;
		if(b[i + 2] == 1)
			h = i + 3;
		else if(b[i + 2] == 0 && b[i + 3] == 1)
			h = i + 4;
		else
			continue;
		if(h >= n)
			break;
		const int t = hevc ? (b[h] >> 1) & 0x3F : b[h] & 0x1F;
		if(hevc ? (t >= 16 && t <= 21) : t == 5)
			return true;
		if(hevc ? (t < 32) : (t >= 1 && t <= 5))
			return false;   // primeira fatia não é chave
		i = h;
	}
	return false;
}

// parâmetros (VPS/SPS/PPS) no começo de um quadro-chave, em Annex B, até a primeira fatia
static QByteArray ParameterSets(const QByteArray &pkt, bool hevc)
{
	const uint8_t *b = reinterpret_cast<const uint8_t *>(pkt.constData());
	const size_t n = size_t(pkt.size());
	for(size_t i = 0; i + 3 < n; i++)
	{
		if(b[i] != 0 || b[i + 1] != 0)
			continue;
		size_t start = i, h;
		if(b[i + 2] == 1)
			h = i + 3;
		else if(b[i + 2] == 0 && b[i + 3] == 1)
			h = i + 4;
		else
			continue;
		if(h >= n)
			break;
		const int t = hevc ? (b[h] >> 1) & 0x3F : b[h] & 0x1F;
		const bool slice = hevc ? t < 32 : (t >= 1 && t <= 5);
		if(slice)
			return pkt.left(int(start));
		i = h;
	}
	return QByteArray();
}

// amostras (a 48 kHz) de um pacote Opus, pela TOC
static int OpusSamples(const uint8_t *b, size_t n)
{
	if(n < 1)
		return 960;
	const int config = b[0] >> 3;
	static const int silk[4] = {10000, 20000, 40000, 60000};
	static const int celt[4] = {2500, 5000, 10000, 20000};
	int us;
	if(config < 12)
		us = silk[config % 4];
	else if(config < 16)
		us = (config % 2) ? 20000 : 10000;
	else
		us = celt[config % 4];
	int frames = 1;
	switch(b[0] & 3)
	{
		case 0: frames = 1; break;
		case 1:
		case 2: frames = 2; break;
		default: frames = n > 1 ? (b[1] & 0x3F) : 1; break;
	}
	return frames * us * 48 / 1000;
}

// ---------------------------------------------------------------- vindo da sessão

void ClipRecorder::beginStream(bool is_hevc, const QString &t, int width, int height)
{
	{
		QMutexLocker l(&mutex);
		ring.clear();
		buffer_bytes = 0;
		hevc = is_hevc;
		title = t;
		video_w = width > 0 ? width : 1920;
		video_h = height > 0 ? height : 1080;
		last_key_us = -1;
		params_latest.clear();
		session_dir.clear();
		last_key_request_us = -1;
		is_streaming = true;
	}
	emit streamingChanged();
}

void ClipRecorder::endStream()
{
	{
		QMutexLocker l(&mutex);
		ring.clear();
		buffer_bytes = 0;
		is_streaming = false;
	}
	emit streamingChanged();
	emit bufferChanged();
}

void ClipRecorder::trimLocked()
{
	if(ring.empty())
		return;
	const qint64 keep_us = qint64(clip_seconds + 12) * 1000000;
	const qint64 newest = ring.back().t_us;
	// teto de 900 MB, só por segurança (90 s de 1080p60 dão uns 170 MB)
	while(!ring.empty() && (newest - ring.front().t_us > keep_us || buffer_bytes > 900ll * 1024 * 1024))
	{
		buffer_bytes -= ring.front().data.size();
		ring.pop_front();
	}
}

void ClipRecorder::pushVideo(const uint8_t *buf, size_t size)
{
	const qint64 now = clock.nsecsElapsed() / 1000;
	const bool key = IsKeyframe(buf, size, hevc);
	bool sinal = false;
	{
		QMutexLocker l(&mutex);
		if(!is_streaming)
			return;
		ring.push_back({QByteArray(reinterpret_cast<const char *>(buf), int(size)), now, true, key});
		if(key)
		{
			const QByteArray ps = ParameterSets(ring.back().data, hevc);
			if(ps.size() > 8)
				params_latest = ps;
		}
		buffer_bytes += qint64(size);
		if(key)
			last_key_us = now;
		const qint64 antes = buffer_bytes / (1024 * 1024);
		trimLocked();
		sinal = (buffer_bytes / (1024 * 1024)) != antes;
	}
	if(sinal)
		emit bufferChanged();
}

void ClipRecorder::setAudioFormat(int channels, int rate)
{
	QMutexLocker l(&mutex);
	audio_channels = channels > 0 ? channels : 2;
	audio_rate = rate > 0 ? rate : 48000;
}

void ClipRecorder::pushAudio(const uint8_t *buf, size_t size)
{
	const qint64 now = clock.nsecsElapsed() / 1000;
	QMutexLocker l(&mutex);
	if(!is_streaming)
		return;
	ring.push_back({QByteArray(reinterpret_cast<const char *>(buf), int(size)), now, false, false});
	buffer_bytes += qint64(size);
}

bool ClipRecorder::wantsKeyframe()
{
	const qint64 now = clock.nsecsElapsed() / 1000;
	QMutexLocker l(&mutex);
	if(!is_streaming)
		return false;
	if(last_key_us >= 0 && now - last_key_us < 8000000)
		return false;
	if(last_key_request_us >= 0 && now - last_key_request_us < 3000000)
		return false;
	last_key_request_us = now;
	return true;
}

// ---------------------------------------------------------------- preferências

void ClipRecorder::setSeconds(int s)
{
	QMutexLocker l(&mutex);
	clip_seconds = qBound(30, s, 300);
}

// uma pasta por transmissão: criada no primeiro clipe, "<data hora> <jogo>"
QString ClipRecorder::startSession(const QString &t)
{
	QString base = t;
	base.replace(QRegularExpression(QStringLiteral("[^\\w\\- ]")), QString());
	base = base.simplified();
	if(base.isEmpty())
		base = QStringLiteral("Jogo");
	session_title = t;
	session_dir = clips_dir + QLatin1Char('/') + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH-mm")) + QLatin1Char(' ') + base;
	QDir().mkpath(session_dir);
	emit libraryChanged();
	return session_dir;
}

QString ClipRecorder::clipsDir() const
{
	return clips_dir;
}

void ClipRecorder::setClipsDir(const QString &dir)
{
	if(!dir.isEmpty())
		clips_dir = dir;
	emit libraryChanged();
}

QString ClipRecorder::tempCaptureDir() const
{
	const QString d = QStandardPaths::writableLocation(QStandardPaths::TempLocation) + QStringLiteral("/IncipitPlay-captura");
	QDir().mkpath(d);
	return d;
}

bool ClipRecorder::removeTemp(const QString &path)
{
	const QFileInfo fi(path);
	if(QDir(fi.absolutePath()) != QDir(tempCaptureDir()) || fi.suffix() != QLatin1String("mkv"))
		return false;
	return QFile::remove(path);
}

QString ClipRecorder::defaultEditingInbox() const
{
	return QString();
}

// ---------------------------------------------------------------- atalho global

bool ClipRecorder::setHotkey(const QString &combo)
{
#ifdef Q_OS_WIN
	if(hotkey_registered)
		UnregisterHotKey(nullptr, HOTKEY_ID);
	hotkey_registered = false;
	unsigned mod = MOD_NOREPEAT, vk = 0;
	const QStringList partes = combo.split(QLatin1Char('+'), Qt::SkipEmptyParts);
	for(QString p : partes)
	{
		p = p.trimmed().toUpper();
		if(p == QLatin1String("ALT")) mod |= MOD_ALT;
		else if(p == QLatin1String("CTRL")) mod |= MOD_CONTROL;
		else if(p == QLatin1String("SHIFT")) mod |= MOD_SHIFT;
		else if(p.startsWith(QLatin1Char('F')) && p.size() > 1) vk = VK_F1 + p.mid(1).toUInt() - 1;
		else if(p.size() == 1) vk = p.at(0).unicode();
	}
	hotkey_text = combo;
	if(vk)
		hotkey_registered = RegisterHotKey(nullptr, HOTKEY_ID, mod, vk);
	hotkey_mod = mod;
	hotkey_vk = vk;
#endif
	emit hotkeyChanged();
	return hotkey_registered;
}

bool ClipRecorder::nativeEventFilter(const QByteArray &type, void *message, qintptr *)
{
#ifdef Q_OS_WIN
	if(type == "windows_dispatcher_MSG" || type == "windows_generic_MSG")
	{
		MSG *msg = static_cast<MSG *>(message);
		if(msg->message == WM_HOTKEY && msg->wParam == HOTKEY_ID)
		{
			QTimer::singleShot(0, this, &ClipRecorder::onHotkey);
			return true;
		}
	}
#endif
	return false;
}

void ClipRecorder::onHotkey()
{
	emit clipRequested();
	if(is_streaming)
		saveNow();
	if(obs_enabled)
		obsSave();
}

// ---------------------------------------------------------------- gravar o mp4

static QString NovoNome(const QString &dir, const QString &title)
{
	QString base = title;
	base.replace(QRegularExpression(QStringLiteral("[^\\w\\- ]")), QString());
	base = base.simplified();
	if(base.isEmpty())
		base = QStringLiteral("Clipe");
	return dir + QLatin1Char('/') + base + QLatin1Char(' ') + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH-mm-ss")) + QStringLiteral(".mp4");
}

struct Recorte { std::vector<QByteArray> data; std::vector<qint64> t; std::vector<char> video; std::vector<char> key; QByteArray params; };

static QString EscreverMp4(const QString &out, const Recorte &r, bool hevc, int w, int h, int channels, int rate, double *dur)
{
	AVFormatContext *fmt = nullptr;
	const QByteArray out8 = QFile::encodeName(out);
	if(avformat_alloc_output_context2(&fmt, nullptr, "mp4", out8.constData()) < 0 || !fmt)
		return QStringLiteral("não deu pra criar o arquivo");

	// vídeo: parâmetros tirados do primeiro quadro-chave, Annex B (o muxer converte)
	QByteArray params;
	size_t first = 0;
	for(; first < r.data.size(); first++)
		if(r.video[first] && r.key[first]) { params = ParameterSets(r.data[first], hevc); break; }
	const bool sem_params_no_quadro = params.size() <= 8;
	if(sem_params_no_quadro)
		params = r.params;       // o quadro-chave do meio da sessão vem sem eles
	AVStream *vs = avformat_new_stream(fmt, nullptr);
	vs->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
	vs->codecpar->codec_id = hevc ? AV_CODEC_ID_HEVC : AV_CODEC_ID_H264;
	vs->codecpar->width = w;
	vs->codecpar->height = h;
	vs->codecpar->extradata = static_cast<uint8_t *>(av_mallocz(size_t(params.size()) + AV_INPUT_BUFFER_PADDING_SIZE));
	memcpy(vs->codecpar->extradata, params.constData(), size_t(params.size()));
	vs->codecpar->extradata_size = params.size();
	vs->time_base = AVRational{1, 90000};
	vs->avg_frame_rate = AVRational{60, 1};

	// áudio: Opus como veio, com o cabeçalho OpusHead
	AVStream *as = avformat_new_stream(fmt, nullptr);
	as->codecpar->codec_type = AVMEDIA_TYPE_AUDIO;
	as->codecpar->codec_id = AV_CODEC_ID_OPUS;
	as->codecpar->sample_rate = 48000;
	av_channel_layout_default(&as->codecpar->ch_layout, channels);
	uint8_t head[19] = {'O', 'p', 'u', 's', 'H', 'e', 'a', 'd', 1, uint8_t(channels), 0x38, 0x01,
		uint8_t(rate & 0xFF), uint8_t((rate >> 8) & 0xFF), uint8_t((rate >> 16) & 0xFF), uint8_t((rate >> 24) & 0xFF), 0, 0, 0};
	as->codecpar->extradata = static_cast<uint8_t *>(av_mallocz(sizeof(head) + AV_INPUT_BUFFER_PADDING_SIZE));
	memcpy(as->codecpar->extradata, head, sizeof(head));
	as->codecpar->extradata_size = sizeof(head);
	as->codecpar->initial_padding = 312;
	as->time_base = AVRational{1, 48000};

	if(avio_open(&fmt->pb, out8.constData(), AVIO_FLAG_WRITE) < 0)
	{
		avformat_free_context(fmt);
		return QStringLiteral("não deu pra escrever na pasta de clipes");
	}
	AVDictionary *opts = nullptr;
	av_dict_set(&opts, "movflags", "+faststart", 0);
	if(avformat_write_header(fmt, &opts) < 0)
	{
		av_dict_free(&opts);
		avio_closep(&fmt->pb);
		avformat_free_context(fmt);
		QFile::remove(out);
		return QStringLiteral("o formato do vídeo não fechou");
	}
	av_dict_free(&opts);

	const qint64 t0 = r.t[first];
	qint64 last_v = -1, audio_pts = -1, fim = t0;
	AVPacket *pkt = av_packet_alloc();
	for(size_t i = first; i < r.data.size(); i++)
	{
		const qint64 rel = r.t[i] - t0;
		if(rel < 0)
			continue;
		av_packet_unref(pkt);
		// o primeiro quadro leva os parâmetros na frente, pra qualquer player abrir sem depender do cabeçalho
		const QByteArray &dado = (i == first && sem_params_no_quadro) ? (params + r.data[i]) : r.data[i];
		if(av_new_packet(pkt, dado.size()) < 0)
			break;
		memcpy(pkt->data, dado.constData(), size_t(dado.size()));
		if(r.video[i])
		{
			qint64 pts = av_rescale_q(rel, AVRational{1, 1000000}, vs->time_base);
			if(pts <= last_v)
				pts = last_v + 1;
			last_v = pts;
			pkt->stream_index = vs->index;
			pkt->pts = pkt->dts = pts;
			if(r.key[i])
				pkt->flags |= AV_PKT_FLAG_KEY;
		}
		else
		{
			const int n = OpusSamples(reinterpret_cast<const uint8_t *>(r.data[i].constData()), size_t(r.data[i].size()));
			if(audio_pts < 0)
				audio_pts = av_rescale_q(rel, AVRational{1, 1000000}, as->time_base);
			pkt->stream_index = as->index;
			pkt->pts = pkt->dts = audio_pts;
			pkt->duration = n;
			audio_pts += n;
		}
		fim = r.t[i];
		if(av_interleaved_write_frame(fmt, pkt) < 0)
			break;
	}
	av_packet_free(&pkt);
	av_write_trailer(fmt);
	avio_closep(&fmt->pb);
	avformat_free_context(fmt);
	if(dur)
		*dur = double(fim - t0) / 1e6;
	return QString();
}

QString ClipRecorder::saveNow()
{
	Recorte r;
	bool is_hevc;
	int ch, rate, secs, w, h;
	QString t;
	{
		QMutexLocker l(&mutex);
		if(!is_streaming || ring.empty())
		{
			emit clipFailed(QStringLiteral("Não tem jogo rodando agora."));
			return QString();
		}
		secs = clip_seconds;
		const qint64 corte = ring.back().t_us - qint64(secs) * 1000000;
		// começa no último quadro-chave antes do corte (ou no primeiro depois, se não houver)
		size_t inicio = 0;
		bool achou = false;
		for(size_t i = 0; i < ring.size(); i++)
		{
			if(ring[i].video && ring[i].key)
			{
				if(ring[i].t_us <= corte || !achou)
				{
					inicio = i;
					achou = true;
				}
				if(ring[i].t_us > corte)
					break;
			}
		}
		if(!achou)
		{
			emit clipFailed(QStringLiteral("Ainda sem quadro-chave do console. Tente de novo em alguns segundos."));
			return QString();
		}
		for(size_t i = inicio; i < ring.size(); i++)
		{
			r.data.push_back(ring[i].data);
			r.t.push_back(ring[i].t_us);
			r.video.push_back(ring[i].video);
			r.key.push_back(ring[i].key);
		}
		r.params = params_latest;
		is_hevc = hevc;
		ch = audio_channels;
		rate = audio_rate;
		w = video_w;
		h = video_h;
		t = title;
	}
	if(session_dir.isEmpty() || session_title != t)
		startSession(t);
	const QString out = NovoNome(session_dir, t);
	(void)QtConcurrent::run([this, out, r = std::move(r), is_hevc, w, h, ch, rate, t]() {
		double dur = 0;
		const QString erro = EscreverMp4(out, r, is_hevc, w, h, ch, rate, &dur);
		QMetaObject::invokeMethod(this, [this, out, erro, t, dur]() {
			if(!erro.isEmpty())
			{
				emit clipFailed(QStringLiteral("O clipe não salvou: ") + erro + QLatin1Char('.'));
				return;
			}
			writeSidecar(out, t, dur);
			makeThumbnail(out);
			emit clipSaved(out, t, dur);
			emit libraryChanged();
		}, Qt::QueuedConnection);
	});
	return out;
}

// fim dos arquivos da placa de captura (gravados em .mkv pela aba Switch): copia sem recodificar
QString ClipRecorder::saveTailOfFiles(const QStringList &files, int seconds, const QString &t)
{
	if(session_dir.isEmpty() || session_title != t)
		startSession(t);
	const QString out = NovoNome(session_dir, t);
	const int secs = qBound(5, seconds, 300);
	(void)QtConcurrent::run([this, files, out, secs, t]() {
		struct P { AVPacket *p; int stream; double t; bool key; };
		std::vector<P> todos;
		AVFormatContext *modelo = nullptr;
		double base = 0, total = 0;
		for(const QString &f : files)
		{
			if(!QFileInfo::exists(f))
				continue;
			AVFormatContext *in = nullptr;
			if(avformat_open_input(&in, QFile::encodeName(f).constData(), nullptr, nullptr) < 0)
				continue;
			avformat_find_stream_info(in, nullptr);
			double fim = base;
			AVPacket *pkt = av_packet_alloc();
			while(av_read_frame(in, pkt) >= 0)
			{
				AVStream *s = in->streams[pkt->stream_index];
				const int64_t ts = pkt->pts != AV_NOPTS_VALUE ? pkt->pts : pkt->dts;
				if(ts == AV_NOPTS_VALUE) { av_packet_unref(pkt); continue; }
				const double tt = base + ts * av_q2d(s->time_base);
				fim = qMax(fim, tt);
				todos.push_back({av_packet_clone(pkt), pkt->stream_index, tt, (pkt->flags & AV_PKT_FLAG_KEY) && s->codecpar->codec_type == AVMEDIA_TYPE_VIDEO});
				av_packet_unref(pkt);
			}
			av_packet_free(&pkt);
			base = fim + 0.02;
			total = fim;
			if(modelo)
				avformat_close_input(&in);
			else
				modelo = in;
		}
		QString erro;
		double dur = 0;
		if(!modelo || todos.empty())
			erro = QStringLiteral("a gravação da placa ainda não começou");
		else
		{
			const double corte = total - secs;
			size_t inicio = 0;
			for(size_t i = 0; i < todos.size(); i++)
				if(todos[i].key && todos[i].t <= corte) inicio = i;
			AVFormatContext *fmt = nullptr;
			const QByteArray out8 = QFile::encodeName(out);
			avformat_alloc_output_context2(&fmt, nullptr, "mp4", out8.constData());
			for(unsigned s = 0; fmt && s < modelo->nb_streams; s++)
			{
				AVStream *os = avformat_new_stream(fmt, nullptr);
				avcodec_parameters_copy(os->codecpar, modelo->streams[s]->codecpar);
				os->codecpar->codec_tag = 0;
				os->time_base = modelo->streams[s]->time_base;
			}
			if(!fmt || avio_open(&fmt->pb, out8.constData(), AVIO_FLAG_WRITE) < 0 || avformat_write_header(fmt, nullptr) < 0)
				erro = QStringLiteral("não deu pra escrever na pasta de clipes");
			else
			{
				const double t0 = todos[inicio].t;
				for(size_t i = inicio; i < todos.size(); i++)
				{
					AVPacket *p = todos[i].p;
					if(todos[i].stream >= int(fmt->nb_streams) || todos[i].t < t0)
						continue;
					AVStream *os = fmt->streams[todos[i].stream];
					const int64_t ts = int64_t((todos[i].t - t0) / av_q2d(os->time_base));
					p->pts = p->dts = ts;
					p->stream_index = todos[i].stream;
					av_interleaved_write_frame(fmt, p);
					dur = todos[i].t - t0;
				}
				av_write_trailer(fmt);
				avio_closep(&fmt->pb);
			}
			if(fmt)
				avformat_free_context(fmt);
			avformat_close_input(&modelo);
		}
		for(auto &p : todos)
			av_packet_free(&p.p);
		QMetaObject::invokeMethod(this, [this, out, erro, t, dur]() {
			if(!erro.isEmpty())
			{
				emit clipFailed(QStringLiteral("O clipe não salvou: ") + erro + QLatin1Char('.'));
				return;
			}
			writeSidecar(out, t, dur);
			makeThumbnail(out);
			emit clipSaved(out, t, dur);
			emit libraryChanged();
		}, Qt::QueuedConnection);
	});
	return out;
}

void ClipRecorder::writeSidecar(const QString &mp4, const QString &t, double seconds)
{
	QJsonObject o;
	o[QStringLiteral("jogo")] = t;
	o[QStringLiteral("segundos")] = qRound(seconds * 10) / 10.0;
	o[QStringLiteral("criado")] = QDateTime::currentDateTime().toString(Qt::ISODate);
	QFile f(mp4.left(mp4.size() - 4) + QStringLiteral(".json"));
	if(f.open(QIODevice::WriteOnly))
		f.write(QJsonDocument(o).toJson());
}

// miniatura: o primeiro quadro do clipe, 480 px de largura
void ClipRecorder::makeThumbnail(const QString &mp4)
{
	auto *player = new QMediaPlayer(this);
	auto *sink = new QVideoSink(player);
	player->setVideoSink(sink);
	const QString jpg = mp4.left(mp4.size() - 4) + QStringLiteral(".jpg");
	connect(sink, &QVideoSink::videoFrameChanged, player, [this, player, jpg](const QVideoFrame &frame) {
		if(!frame.isValid())
			return;
		const QImage img = frame.toImage();
		if(img.isNull())
			return;
		img.scaledToWidth(480, Qt::SmoothTransformation).save(jpg, "JPG", 85);
		player->stop();
		player->deleteLater();
		emit libraryChanged();
	});
	connect(player, &QMediaPlayer::errorOccurred, player, [player]() { player->deleteLater(); });
	QTimer::singleShot(15000, player, [player]() { player->deleteLater(); });
	player->setSource(QUrl::fromLocalFile(mp4));
	player->play();
}

// ---------------------------------------------------------------- biblioteca

static QVariantMap DadosDoClipe(const QFileInfo &fi)
{
	QVariantMap m;
	m[QStringLiteral("caminho")] = fi.absoluteFilePath();
	m[QStringLiteral("nome")] = fi.completeBaseName();
	m[QStringLiteral("criado")] = fi.lastModified();
	m[QStringLiteral("tamanhoMb")] = qRound(fi.size() / 1048576.0 * 10) / 10.0;
	const QString base = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName();
	QFile js(base + QStringLiteral(".json"));
	if(js.open(QIODevice::ReadOnly))
	{
		const QJsonObject o = QJsonDocument::fromJson(js.readAll()).object();
		m[QStringLiteral("jogo")] = o.value(QStringLiteral("jogo")).toString();
		m[QStringLiteral("segundos")] = o.value(QStringLiteral("segundos")).toDouble();
		m[QStringLiteral("enviado")] = o.value(QStringLiteral("enviado")).toBool();
	}
	const QString jpg = base + QStringLiteral(".jpg");
	m[QStringLiteral("miniatura")] = QFileInfo::exists(jpg) ? QUrl::fromLocalFile(jpg).toString() + QStringLiteral("?") + QString::number(QFileInfo(jpg).lastModified().toMSecsSinceEpoch()) : QString();
	return m;
}

QVariantList ClipRecorder::library() const
{
	QVariantList sessoes;
	QDir d(clips_dir);
	const QStringList mp4 = {QStringLiteral("*.mp4")};
	const QFileInfoList pastas = d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::Reversed);
	auto juntar = [&](const QFileInfo &pasta, bool atual) {
		QVariantList clipes;
		for(const QFileInfo &fi : QDir(pasta.absoluteFilePath()).entryInfoList(mp4, QDir::Files, QDir::Time))
			clipes.append(DadosDoClipe(fi));
		if(clipes.isEmpty() && !atual)
			return;
		QVariantMap s;
		s[QStringLiteral("pasta")] = pasta.absoluteFilePath();
		s[QStringLiteral("nome")] = pasta.fileName();
		s[QStringLiteral("atual")] = atual;
		s[QStringLiteral("clipes")] = clipes;
		sessoes.append(s);
	};
	if(!session_dir.isEmpty())
		juntar(QFileInfo(session_dir), true);
	for(const QFileInfo &p : pastas)
		if(QDir(p.absoluteFilePath()) != QDir(session_dir))
			juntar(p, false);
	// clipes soltos na raiz (versão antiga ou copiados à mão)
	QVariantList soltos;
	for(const QFileInfo &fi : d.entryInfoList(mp4, QDir::Files, QDir::Time))
		soltos.append(DadosDoClipe(fi));
	if(!soltos.isEmpty())
		sessoes.append(QVariantMap{{QStringLiteral("pasta"), clips_dir}, {QStringLiteral("nome"), QStringLiteral("Outros clipes")}, {QStringLiteral("atual"), false}, {QStringLiteral("clipes"), soltos}});
	return sessoes;
}

bool ClipRecorder::trash(const QString &path)
{
	const QFileInfo fi(path);
	const QString raiz = QDir(clips_dir).canonicalPath() + QLatin1Char('/');
	if(!fi.exists() || !fi.canonicalFilePath().startsWith(raiz, Qt::CaseInsensitive) || fi.suffix().compare(QStringLiteral("mp4"), Qt::CaseInsensitive) != 0)
		return false;
	const QString base = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName();
	const bool ok = QFile::moveToTrash(path);
	QFile::moveToTrash(base + QStringLiteral(".json"));
	QFile::moveToTrash(base + QStringLiteral(".jpg"));
	emit libraryChanged();
	return ok;
}

QString ClipRecorder::sendToEditing(const QString &path, const QString &inbox, const QString &pedido)
{
	const QFileInfo fi(path);
	if(!fi.exists() || inbox.isEmpty())
		return QString();
	QDir().mkpath(inbox);
	const QString dest = inbox + QLatin1Char('/') + fi.fileName();
	if(!QFileInfo::exists(dest) && !QFile::copy(path, dest))
		return QString();
	const QString base = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName();
	// o pedido vai junto: um .json (pra máquina) e um .txt (pra quem abrir a pasta)
	QJsonObject o;
	QFile js(base + QStringLiteral(".json"));
	if(js.open(QIODevice::ReadOnly))
		o = QJsonDocument::fromJson(js.readAll()).object();
	js.close();
	o[QStringLiteral("pedido")] = pedido.left(2000);
	o[QStringLiteral("clipe")] = fi.fileName();
	o[QStringLiteral("enviado_em")] = QDateTime::currentDateTime().toString(Qt::ISODate);
	QFile out(inbox + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(".json"));
	if(out.open(QIODevice::WriteOnly))
		out.write(QJsonDocument(o).toJson());
	QFile txt(inbox + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(".txt"));
	if(txt.open(QIODevice::WriteOnly | QIODevice::Text))
		txt.write((QStringLiteral("Clipe: ") + fi.fileName() + QStringLiteral("\nPedido: ") + pedido.left(2000) + QStringLiteral("\n")).toUtf8());
	// marca na biblioteca que já foi
	QJsonObject marca;
	if(js.open(QIODevice::ReadOnly)) { marca = QJsonDocument::fromJson(js.readAll()).object(); js.close(); }
	marca[QStringLiteral("enviado")] = true;
	if(js.open(QIODevice::WriteOnly)) js.write(QJsonDocument(marca).toJson());
	emit libraryChanged();
	return dest;
}

// ---------------------------------------------------------------- OBS (obs-websocket 5)

void ClipRecorder::setObs(bool enabled, int port, const QString &password)
{
	obs_enabled = enabled;
	obs_port = port > 0 ? port : 4455;
	obs_password = password;
}

static void ObsRequest(ClipRecorder *self, int port, const QString &password, const QString &request,
	std::function<void(bool, const QString &)> done)
{
	auto *ws = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, self);
	auto terminou = std::make_shared<bool>(false);
	auto fim = [ws, terminou, done](bool ok, const QString &txt) {
		if(*terminou)
			return;
		*terminou = true;
		done(ok, txt);
		ws->close();
		ws->deleteLater();
	};
	QObject::connect(ws, &QWebSocket::textMessageReceived, ws, [ws, password, request, fim](const QString &txt) {
		const QJsonObject m = QJsonDocument::fromJson(txt.toUtf8()).object();
		const int op = m.value(QStringLiteral("op")).toInt();
		const QJsonObject d = m.value(QStringLiteral("d")).toObject();
		if(op == 0)
		{
			QJsonObject id{{QStringLiteral("rpcVersion"), 1}};
			const QJsonObject auth = d.value(QStringLiteral("authentication")).toObject();
			if(!auth.isEmpty())
			{
				const QByteArray secret = QCryptographicHash::hash((password + auth.value(QStringLiteral("salt")).toString()).toUtf8(), QCryptographicHash::Sha256).toBase64();
				const QByteArray resp = QCryptographicHash::hash(secret + auth.value(QStringLiteral("challenge")).toString().toUtf8(), QCryptographicHash::Sha256).toBase64();
				id[QStringLiteral("authentication")] = QString::fromLatin1(resp);
			}
			ws->sendTextMessage(QString::fromUtf8(QJsonDocument(QJsonObject{{QStringLiteral("op"), 1}, {QStringLiteral("d"), id}}).toJson(QJsonDocument::Compact)));
		}
		else if(op == 2)
		{
			const QJsonObject req{{QStringLiteral("requestType"), request}, {QStringLiteral("requestId"), QStringLiteral("incipit-play")}};
			ws->sendTextMessage(QString::fromUtf8(QJsonDocument(QJsonObject{{QStringLiteral("op"), 6}, {QStringLiteral("d"), req}}).toJson(QJsonDocument::Compact)));
		}
		else if(op == 7)
		{
			const QJsonObject st = d.value(QStringLiteral("requestStatus")).toObject();
			const bool ok = st.value(QStringLiteral("result")).toBool();
			const QJsonObject resp = d.value(QStringLiteral("responseData")).toObject();
			QString texto;
			if(request == QLatin1String("GetReplayBufferStatus"))
				texto = !ok ? QStringLiteral("O OBS respondeu, mas o Replay Buffer não está configurado.")
					: resp.value(QStringLiteral("outputActive")).toBool() ? QStringLiteral("OBS conectado e Replay Buffer ligado.")
					: QStringLiteral("OBS conectado, mas o Replay Buffer está desligado (ligue em Controles > Iniciar Replay Buffer).");
			else
				texto = ok ? QStringLiteral("O OBS salvou o Replay Buffer.") : QStringLiteral("O OBS não salvou: o Replay Buffer está desligado?");
			fim(ok && (request != QLatin1String("GetReplayBufferStatus") || resp.value(QStringLiteral("outputActive")).toBool()), texto);
		}
	});
	QObject::connect(ws, &QWebSocket::disconnected, ws, [fim]() {
		fim(false, QStringLiteral("O OBS fechou a conexão. Confira a senha em Ferramentas > Configurações do servidor WebSocket."));
	});
	QObject::connect(ws, &QWebSocket::errorOccurred, ws, [fim](QAbstractSocket::SocketError) {
		fim(false, QStringLiteral("O OBS não respondeu. Ele está aberto, com o servidor WebSocket ligado?"));
	});
	QTimer::singleShot(4000, ws, [fim]() { fim(false, QStringLiteral("O OBS não respondeu a tempo.")); });
	ws->open(QUrl(QStringLiteral("ws://127.0.0.1:%1").arg(port)));
}

void ClipRecorder::obsSave()
{
	ObsRequest(this, obs_port, obs_password, QStringLiteral("SaveReplayBuffer"), [this](bool ok, const QString &t) { emit obsStatus(t, ok); });
}

void ClipRecorder::testObs()
{
	ObsRequest(this, obs_port, obs_password, QStringLiteral("GetReplayBufferStatus"), [this](bool ok, const QString &t) { emit obsStatus(t, ok); });
}

// Incipit Play · edição automática dos clipes. Ver incipitedicao.h.
#include "incipitedicao.h"
#include "cliprecorder.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#ifdef Q_OS_WIN
#include <windows.h>
#endif

// ---------------------------------------------------------------- o pacote de edição
// Montado por edicao/pacote/montar_pacote.py e publicado como asset de um release próprio (não o Latest) em
// dalmor0/incipit-releases. O Play só usa o arquivo se o tamanho e o SHA-256 baterem com estes.
static const char *PACOTE_VERSAO = "1.0.1";
static const char *PACOTE_URL = "https://github.com/dalmor0/incipit-releases/releases/download/edicao-1.0.1/IncipitPlay-Edicao-1.0.1.zip";
static const char *PACOTE_SHA256 = "aec4bb7fb55037b6c80076fd07ca99d18b7bb73f5e0875a5b5f0ab8e912a294a";
static const qint64 PACOTE_TAMANHO = 145662900;
static const qint64 ESPACO_MINIMO = qint64(3) * 1024 * 1024 * 1024;   // pacote aberto + leitor de fala (1,5 GB) + folga

IncipitEdicao *IncipitEdicao::instance()
{
	static IncipitEdicao *e = new IncipitEdicao(QCoreApplication::instance());
	return e;
}

IncipitEdicao::IncipitEdicao(QObject *parent) : QObject(parent)
{
	// o jogo abriu ou fechou: a fila anda ou a edição baixa a prioridade
	connect(ClipRecorder::instance(), &ClipRecorder::streamingChanged, this, [this]() {
		if(m_estado == QStringLiteral("fila") && !ClipRecorder::instance()->streaming())
			comecar();
		ajustarPrioridade();
	}, Qt::QueuedConnection);
	connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() { encerrarProcesso(); });
}

static QString base()
{
	// teste de "PC limpo" com outro disco: INCIPIT_EDICAO_BASE troca a pasta do editor, do leitor de fala e do log
	const QString teste = qEnvironmentVariable("INCIPIT_EDICAO_BASE");
	if(!teste.isEmpty())
		return QDir::cleanPath(teste);
	return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
}

QString IncipitEdicao::raizPacote() const
{
	// desenvolvimento: INCIPIT_EDICAO_DIR aponta pra uma pasta de pacote já aberta
	const QString dev = qEnvironmentVariable("INCIPIT_EDICAO_DIR");
	if(!dev.isEmpty())
		return QDir::cleanPath(dev);
	return base() + QStringLiteral("/edicao/") + QString::fromLatin1(PACOTE_VERSAO);
}

QString IncipitEdicao::pythonDoPacote() const
{
	return raizPacote() + QStringLiteral("/python/python.exe");
}

bool IncipitEdicao::pacotePronto() const
{
	return QFileInfo::exists(pythonDoPacote()) && QFileInfo::exists(raizPacote() + QStringLiteral("/clipador/__main__.py"))
		&& QFileInfo::exists(raizPacote() + QStringLiteral("/bin/ffmpeg.exe"));
}

bool IncipitEdicao::travada() const
{
	// trava de cobrança pronta e desligada (decisão do Gustavo pendente): edicao/travaPlano = true liga
	return QSettings().value(QStringLiteral("edicao/travaPlano"), false).toBool()
		&& !QSettings().value(QStringLiteral("edicao/planoAtivo"), false).toBool();
}

void IncipitEdicao::definir(const QString &estado, double pct, const QString &etapa)
{
	m_estado = estado;
	m_pct = pct;
	m_etapa = etapa;
	emit mudou();
}

void IncipitEdicao::registrar(const QString &linha) const
{
	const QString pasta = base() + QStringLiteral("/log");
	QDir().mkpath(pasta);
	QFile f(pasta + QStringLiteral("/edicao.log"));
	if(f.size() > 2 * 1024 * 1024)
		f.remove();
	if(f.open(QIODevice::Append | QIODevice::Text))
		f.write((QDateTime::currentDateTime().toString(Qt::ISODate) + QStringLiteral(" ") + linha.left(4000) + QStringLiteral("\n")).toUtf8());
}

QString IncipitEdicao::pastaSaida() const
{
	return ClipRecorder::instance()->clipsDir() + QStringLiteral("/Editados");
}

static bool dentroDe(const QString &arquivo, const QString &pasta)
{
	const QString raiz = QDir(pasta).canonicalPath();
	const QString alvo = QFileInfo(arquivo).canonicalFilePath();
	return !raiz.isEmpty() && !alvo.isEmpty() && alvo.startsWith(raiz + QLatin1Char('/'), Qt::CaseInsensitive);
}

// ---------------------------------------------------------------- pedir uma edição

bool IncipitEdicao::editar(const QString &clipe, const QVariantMap &opcoes)
{
	if(m_estado == QStringLiteral("baixando") || m_estado == QStringLiteral("editando") || m_estado == QStringLiteral("fila"))
		return false;
	if(travada())
	{
		m_motivo = QStringLiteral("A edição automática faz parte de um plano pago.");
		definir(QStringLiteral("erro"), 0, QString());
		return false;
	}
	// só clipe da biblioteca: arquivo de vídeo de verdade, dentro da pasta dos clipes
	const QFileInfo fi(clipe);
	const QString ext = fi.suffix().toLower();
	if(!fi.isFile() || !(ext == QStringLiteral("mp4") || ext == QStringLiteral("mkv") || ext == QStringLiteral("mov"))
		|| !dentroDe(clipe, ClipRecorder::instance()->clipsDir()))
	{
		m_motivo = QStringLiteral("Esse arquivo não está na pasta dos clipes.");
		definir(QStringLiteral("erro"), 0, QString());
		return false;
	}
	m_clipe = fi.canonicalFilePath();
	m_opcoes = opcoes;
	m_resultado.clear();
	m_motivo.clear();
	m_cancelado = false;
	m_furouFila = false;
	if(!pacotePronto())
	{
		baixarPacote();
		return true;
	}
	if(ClipRecorder::instance()->streaming())
	{
		definir(QStringLiteral("fila"), 0, QStringLiteral("Começa quando você sair do jogo"));
		return true;
	}
	comecar();
	return true;
}

void IncipitEdicao::editarAgora()
{
	if(m_estado != QStringLiteral("fila"))
		return;
	m_furouFila = true;
	comecar();
}

void IncipitEdicao::fechar()
{
	if(m_estado == QStringLiteral("pronto") || m_estado == QStringLiteral("erro"))
	{
		m_motivo.clear();
		definir(QStringLiteral("livre"), 0, QString());
	}
}

// ---------------------------------------------------------------- primeira vez: baixar o pacote

void IncipitEdicao::baixarPacote()
{
	if(!qEnvironmentVariable("INCIPIT_EDICAO_DIR").isEmpty())
	{
		falhar(QStringLiteral("O pacote de edição está incompleto (falta o ffmpeg)."));
		return;
	}
	if(QByteArray(PACOTE_SHA256).size() != 64 || PACOTE_TAMANHO <= 0)
	{
		falhar(QStringLiteral("Esta versão do Play ainda não tem o editor. Atualize o Incipit Play."));
		return;
	}
	QDir().mkpath(base() + QStringLiteral("/edicao"));
	if(QStorageInfo(base()).bytesAvailable() < ESPACO_MINIMO)
	{
		falhar(QStringLiteral("Falta espaço no disco: a primeira edição precisa de uns 3 GB livres."));
		return;
	}
	if(!m_rede)
		m_rede = new QNetworkAccessManager(this);
	const QString parcial = base() + QStringLiteral("/edicao/pacote.baixando");
	QFile::remove(parcial);
	m_arquivo = new QFile(parcial, this);
	if(!m_arquivo->open(QIODevice::WriteOnly))
	{
		delete m_arquivo;
		m_arquivo = nullptr;
		falhar(QStringLiteral("Não deu pra gravar o editor no disco."));
		return;
	}
	m_hash.reset();
	m_baixado = 0;
	QNetworkRequest req{QUrl(QString::fromLatin1(PACOTE_URL))};
	req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
	req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("IncipitPlay"));
	req.setTransferTimeout(30000);   // rede parada 30 s: erro, não espera pra sempre
	m_download = m_rede->get(req);
	definir(QStringLiteral("baixando"), 0, QStringLiteral("Preparando o editor (só na primeira vez)"));
	connect(m_download, &QNetworkReply::readyRead, this, [this]() {
		if(!m_download || !m_arquivo)
			return;
		const QByteArray b = m_download->readAll();
		m_baixado += b.size();
		if(m_baixado > PACOTE_TAMANHO)
		{
			m_download->abort();
			return;
		}
		m_hash.addData(b);
		m_arquivo->write(b);
		m_pct = 100.0 * m_baixado / PACOTE_TAMANHO;
		m_etapa = QStringLiteral("Preparando o editor (só na primeira vez): %1 de %2 MB")
			.arg(m_baixado / 1000000).arg(PACOTE_TAMANHO / 1000000);
		emit mudou();
	});
	connect(m_download, &QNetworkReply::finished, this, [this]() {
		QNetworkReply *r = m_download;
		m_download = nullptr;
		r->deleteLater();
		const QString caminho = m_arquivo->fileName();
		m_arquivo->close();
		m_arquivo->deleteLater();
		m_arquivo = nullptr;
		if(m_cancelado)
		{
			QFile::remove(caminho);
			definir(QStringLiteral("livre"), 0, QString());
			return;
		}
		if(r->error() != QNetworkReply::NoError)
		{
			QFile::remove(caminho);
			registrar(QStringLiteral("download: ") + r->errorString());
			falhar(m_baixado > PACOTE_TAMANHO ? QStringLiteral("O editor baixado veio diferente do original e foi descartado.")
				: QStringLiteral("Não deu pra baixar o editor. Confira a internet e tente de novo."));
			return;
		}
		if(m_baixado != PACOTE_TAMANHO || m_hash.result().toHex() != QByteArray(PACOTE_SHA256))
		{
			QFile::remove(caminho);
			registrar(QStringLiteral("download: hash diferente ") + QString::fromLatin1(m_hash.result().toHex()));
			falhar(QStringLiteral("O editor baixado veio diferente do original e foi descartado. Tente de novo."));
			return;
		}
		instalarPacote(caminho);
	});
}

void IncipitEdicao::instalarPacote(const QString &zip)
{
	definir(QStringLiteral("baixando"), 100, QStringLiteral("Abrindo o editor"));
	const QString destino = raizPacote();
	const QString temp = destino + QStringLiteral(".abrindo");
	QDir(temp).removeRecursively();
	QDir().mkpath(temp);
	// tar.exe do próprio Windows (assinado pela Microsoft) abre o zip; o arquivo já foi conferido pelo SHA-256
	auto *tar = new QProcess(this);
	const QString tarExe = QDir::fromNativeSeparators(qEnvironmentVariable("SystemRoot", QStringLiteral("C:/Windows"))) + QStringLiteral("/System32/tar.exe");
	tar->setProgram(tarExe);
	tar->setArguments({QStringLiteral("-xf"), QDir::toNativeSeparators(zip), QStringLiteral("-C"), QDir::toNativeSeparators(temp)});
	connect(tar, &QProcess::finished, this, [this, tar, zip, temp, destino](int code, QProcess::ExitStatus st) {
		tar->deleteLater();
		QFile::remove(zip);
		if(st != QProcess::NormalExit || code != 0 || !QFileInfo::exists(temp + QStringLiteral("/python/python.exe")))
		{
			registrar(QStringLiteral("tar: ") + QString::fromLocal8Bit(tar->readAllStandardError()));
			QDir(temp).removeRecursively();
			falhar(QStringLiteral("Não deu pra abrir o editor no disco. Tente de novo."));
			return;
		}
		if(destino.startsWith(base() + QStringLiteral("/edicao/")))
			QDir(destino).removeRecursively();
		if(!QDir().rename(temp, destino))
		{
			QDir(temp).removeRecursively();
			falhar(QStringLiteral("Não deu pra abrir o editor no disco. Tente de novo."));
			return;
		}
		// versões antigas do pacote saem
		QDir pasta(base() + QStringLiteral("/edicao"));
		for(const QString &d : pasta.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
			if(d != QString::fromLatin1(PACOTE_VERSAO))
				QDir(pasta.filePath(d)).removeRecursively();
		if(m_cancelado)
		{
			definir(QStringLiteral("livre"), 0, QString());
			return;
		}
		if(ClipRecorder::instance()->streaming())
			definir(QStringLiteral("fila"), 0, QStringLiteral("Começa quando você sair do jogo"));
		else
			comecar();
	});
	tar->start();
}

// ---------------------------------------------------------------- rodar o clipador

void IncipitEdicao::comecar()
{
	m_buffer.clear();
	m_recebeuFim = false;
	const QString saida = pastaSaida();
	QDir().mkpath(saida);
	QStringList args = {QStringLiteral("-I"), QStringLiteral("-X"), QStringLiteral("utf8"), QStringLiteral("-m"), QStringLiteral("clipador"),
		QStringLiteral("editar"), QStringLiteral("--clipe=") + QDir::toNativeSeparators(m_clipe),
		QStringLiteral("--saida=") + QDir::toNativeSeparators(saida)};
	const QString pedido = m_opcoes.value(QStringLiteral("pedido")).toString().left(500).simplified();
	if(!pedido.isEmpty())
		args << QStringLiteral("--pedido=") + pedido;
	const QString layout = m_opcoes.value(QStringLiteral("layout")).toString();
	if(QStringList{QStringLiteral("camera"), QStringLiteral("centro"), QStringLiteral("desfocado")}.contains(layout))
		args << QStringLiteral("--layout") << layout;
	const QString estilo = m_opcoes.value(QStringLiteral("estilo")).toString();
	if(QStringList{QStringLiteral("creme"), QStringLiteral("amarela"), QStringLiteral("destaque"), QStringLiteral("limpa")}.contains(estilo))
		args << QStringLiteral("--estilo") << estilo;
	if(m_opcoes.value(QStringLiteral("semLegenda")).toBool())
		args << QStringLiteral("--sem-legenda");
	const QString titulo = m_opcoes.value(QStringLiteral("titulo")).toString().left(60).simplified();
	if(!titulo.isEmpty())
		args << QStringLiteral("--titulo=") + titulo;
	const double zoom = m_opcoes.value(QStringLiteral("zoom"), -1).toDouble();
	if(zoom == 0.0 || zoom == 0.5 || zoom == 1.0 || zoom == 2.0)
		args << QStringLiteral("--zoom") << QString::number(zoom, 'f', 1);
	const double ini = m_opcoes.value(QStringLiteral("inicio"), -1).toDouble();
	const double fim = m_opcoes.value(QStringLiteral("fim"), -1).toDouble();
	if(ini >= 0 && fim > ini)
		args << QStringLiteral("--inicio") << QString::number(ini, 'f', 2) << QStringLiteral("--fim") << QString::number(fim, 'f', 2);
	const QVariantList cam = m_opcoes.value(QStringLiteral("camera")).toList();
	if(cam.size() == 4)
	{
		QStringList c;
		for(const QVariant &v : cam)
			c << QString::number(qBound(0.0, v.toDouble(), 1.0), 'f', 4);
		args << QStringLiteral("--camera") << c.join(QLatin1Char(','));
	}
	const QString musica = m_opcoes.value(QStringLiteral("musica")).toString();
	if(!musica.isEmpty() && QFileInfo(musica).isDir())
		args << QStringLiteral("--musica=") + QDir::toNativeSeparators(musica);
	if(QSettings().value(QStringLiteral("idioma/lingua")).toString() == QStringLiteral("en"))
		args << QStringLiteral("--idioma") << QStringLiteral("auto");

	m_proc = new QProcess(this);
	m_proc->setProgram(pythonDoPacote());
	m_proc->setArguments(args);
	m_proc->setWorkingDirectory(QDir::tempPath());
	QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
	env.insert(QStringLiteral("INCIPIT_EDICAO_ENTRADA"), QStringLiteral("1"));
	env.insert(QStringLiteral("INCIPIT_EDICAO_MODELOS"), QDir::toNativeSeparators(base() + QStringLiteral("/modelos")));
	env.insert(QStringLiteral("INCIPIT_EDICAO_CACHE"), QDir::toNativeSeparators(base() + QStringLiteral("/edicao-cache")));
	env.remove(QStringLiteral("PYTHONHOME"));
	env.remove(QStringLiteral("PYTHONPATH"));
	m_proc->setProcessEnvironment(env);
#ifdef Q_OS_WIN
	m_proc->setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *a) {
		a->flags |= CREATE_NO_WINDOW | BELOW_NORMAL_PRIORITY_CLASS;
	});
#endif
	connect(m_proc, &QProcess::readyReadStandardOutput, this, &IncipitEdicao::lerSaida);
	connect(m_proc, &QProcess::readyReadStandardError, this, [this]() {
		registrar(QString::fromUtf8(m_proc->readAllStandardError()).trimmed());
	});
	connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
		lerSaida();
		QProcess *p = m_proc;
		m_proc = nullptr;
		p->deleteLater();
#ifdef Q_OS_WIN
		if(m_job) { CloseHandle((HANDLE)m_job); m_job = nullptr; }
#endif
		// sobra de vídeo pela metade (cancelado ou morto) não fica na pasta
		QDir d(pastaSaida());
		for(const QString &f : d.entryList({QStringLiteral("*.parcial.mp4")}, QDir::Files))
			d.remove(f);
		if(m_cancelado)
		{
			definir(QStringLiteral("livre"), 0, QString());
			emit terminou(false);
			return;
		}
		if(!m_recebeuFim)
		{
			registrar(QStringLiteral("clipador saiu com %1 sem resposta").arg(code));
			falhar(QStringLiteral("A edição parou no meio. Tente de novo; se repetir, o detalhe fica no log."));
		}
	});
	connect(m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
		if(e == QProcess::FailedToStart)
		{
			registrar(QStringLiteral("clipador não abriu: ") + m_proc->errorString());
			m_proc->deleteLater();
			m_proc = nullptr;
			falhar(QStringLiteral("O editor não abriu. O Windows pode ter bloqueado o programa (Smart App Control)."));
		}
	});
	definir(QStringLiteral("editando"), 0, QStringLiteral("Preparando"));
	registrar(QStringLiteral("editar ") + m_clipe);
	m_proc->start();
#ifdef Q_OS_WIN
	if(m_proc && m_proc->processId())
	{
		// Job: ele e os filhos (ffmpeg) morrem juntos no cancelar ou se o Play fechar; a prioridade vale pra todos
		HANDLE job = CreateJobObjectW(nullptr, nullptr);
		HANDLE h = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE, (DWORD)m_proc->processId());
		if(job && h && AssignProcessToJobObject(job, h))
			m_job = job;
		else if(job)
			CloseHandle(job);
		if(h)
			CloseHandle(h);
		ajustarPrioridade();
	}
#endif
}

void IncipitEdicao::ajustarPrioridade()
{
#ifdef Q_OS_WIN
	if(!m_job)
		return;
	JOBOBJECT_EXTENDED_LIMIT_INFORMATION lim = {};
	lim.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_PRIORITY_CLASS | JOB_OBJECT_LIMIT_JOB_MEMORY;
	lim.JobMemoryLimit = SIZE_T(6) * 1024 * 1024 * 1024;
	lim.BasicLimitInformation.PriorityClass = ClipRecorder::instance()->streaming() ? IDLE_PRIORITY_CLASS : BELOW_NORMAL_PRIORITY_CLASS;
	SetInformationJobObject((HANDLE)m_job, JobObjectExtendedLimitInformation, &lim, sizeof(lim));
#endif
}

void IncipitEdicao::lerSaida()
{
	if(!m_proc)
		return;
	m_buffer += m_proc->readAllStandardOutput();
	int nl;
	while((nl = m_buffer.indexOf('\n')) >= 0)
	{
		const QByteArray linha = m_buffer.left(nl).trimmed();
		m_buffer.remove(0, nl + 1);
		if(linha.isEmpty() || linha.size() > 1024 * 1024)
			continue;
		const QJsonObject o = QJsonDocument::fromJson(linha).object();
		const QString tipo = o.value(QStringLiteral("tipo")).toString();
		if(tipo == QStringLiteral("etapa"))
		{
			m_pct = qBound(0.0, o.value(QStringLiteral("pct")).toDouble(), 100.0);
			m_etapa = o.value(QStringLiteral("texto")).toString().left(200);
			emit mudou();
		}
		else if(tipo == QStringLiteral("pronto"))
		{
			m_recebeuFim = true;
			m_resultado = o.toVariantMap();
			m_resultado[QStringLiteral("miniaturaUrl")] = QUrl::fromLocalFile(o.value(QStringLiteral("miniatura")).toString()).toString();
			registrar(QStringLiteral("pronto ") + o.value(QStringLiteral("arquivo")).toString());
			definir(QStringLiteral("pronto"), 100, QString());
			emit editadosMudaram();
			emit terminou(true);
		}
		else if(tipo == QStringLiteral("erro"))
		{
			m_recebeuFim = true;
			registrar(QStringLiteral("erro ") + o.value(QStringLiteral("motivo")).toString() + QStringLiteral(" | ") + o.value(QStringLiteral("detalhe")).toString());
			if(o.value(QStringLiteral("cancelado")).toBool() || m_cancelado)
			{
				m_cancelado = true;
				continue;
			}
			falhar(o.value(QStringLiteral("motivo")).toString().left(300));
		}
	}
}

void IncipitEdicao::falhar(const QString &motivo)
{
	m_motivo = motivo;
	definir(QStringLiteral("erro"), 0, QString());
	emit terminou(false);
}

void IncipitEdicao::cancelar()
{
	m_cancelado = true;
	if(m_estado == QStringLiteral("fila"))
	{
		definir(QStringLiteral("livre"), 0, QString());
		return;
	}
	if(m_download)
	{
		m_download->abort();
		return;
	}
	if(m_proc)
	{
		m_proc->write("cancelar\n");
		definir(QStringLiteral("editando"), m_pct, QStringLiteral("Cancelando"));
		// se em 3 s não saiu sozinho, o Windows derruba o Job inteiro (Python e ffmpeg)
		QPointer<QProcess> p = m_proc;
		QTimer::singleShot(3000, this, [this, p]() {
			if(p && p == m_proc)
				encerrarProcesso();
		});
	}
}

void IncipitEdicao::encerrarProcesso()
{
#ifdef Q_OS_WIN
	if(m_job)
		TerminateJobObject((HANDLE)m_job, 1);
#endif
	if(m_proc)
		m_proc->kill();
	if(m_download)
		m_download->abort();
}

// ---------------------------------------------------------------- editados

void IncipitEdicao::mostrarNaPasta(const QString &arquivo) const
{
	if(!dentroDe(arquivo, pastaSaida()))
	{
		QDir().mkpath(pastaSaida());
		QProcess::startDetached(QDir::fromNativeSeparators(qEnvironmentVariable("SystemRoot", QStringLiteral("C:/Windows"))) + QStringLiteral("/explorer.exe"), {QDir::toNativeSeparators(pastaSaida())});
		return;
	}
#ifdef Q_OS_WIN
	QProcess p;
	p.setProgram(QDir::fromNativeSeparators(qEnvironmentVariable("SystemRoot", QStringLiteral("C:/Windows"))) + QStringLiteral("/explorer.exe"));
	p.setNativeArguments(QStringLiteral("/select,\"") + QDir::toNativeSeparators(arquivo) + QStringLiteral("\""));
	p.startDetached();
#endif
}

QVariantList IncipitEdicao::editados(int limite) const
{
	QVariantList out;
	QDir d(pastaSaida());
	const QFileInfoList js = d.entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Time);
	for(const QFileInfo &j : js)
	{
		if(out.size() >= limite)
			break;
		QFile f(j.filePath());
		if(f.size() > 256 * 1024 || !f.open(QIODevice::ReadOnly))
			continue;
		QVariantMap m = QJsonDocument::fromJson(f.readAll()).object().toVariantMap();
		const QString mp4 = j.absolutePath() + QLatin1Char('/') + j.completeBaseName() + QStringLiteral(".mp4");
		if(!QFileInfo::exists(mp4))
			continue;
		m[QStringLiteral("arquivo")] = mp4;
		m[QStringLiteral("miniatura")] = QUrl::fromLocalFile(j.absolutePath() + QLatin1Char('/') + j.completeBaseName() + QStringLiteral(".jpg")).toString();
		m[QStringLiteral("criado")] = j.lastModified();
		m.remove(QStringLiteral("onda"));
		out << m;
	}
	return out;
}

QString IncipitEdicao::editadoDe(const QString &clipe) const
{
	const QString alvo = QFileInfo(clipe).canonicalFilePath();
	for(const QVariant &v : editados(60))
	{
		const QVariantMap m = v.toMap();
		if(QFileInfo(m.value(QStringLiteral("origem")).toString()).canonicalFilePath().compare(alvo, Qt::CaseInsensitive) == 0)
			return m.value(QStringLiteral("arquivo")).toString();
	}
	return QString();
}

bool IncipitEdicao::apagarEditado(const QString &arquivo)
{
	if(!dentroDe(arquivo, pastaSaida()) || QFileInfo(arquivo).suffix().compare(QStringLiteral("mp4"), Qt::CaseInsensitive) != 0)
		return false;
	const QFileInfo fi(arquivo);
	const QString b = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName();
	const bool ok = QFile::moveToTrash(arquivo);
	QFile::moveToTrash(b + QStringLiteral(".json"));
	QFile::moveToTrash(b + QStringLiteral(".jpg"));
	emit editadosMudaram();
	return ok;
}

QString IncipitEdicao::quadroDoClipe(const QString &clipe) const
{
	const QFileInfo fi(clipe);
	const QString jpg = fi.absolutePath() + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(".jpg");
	return QFileInfo::exists(jpg) ? QUrl::fromLocalFile(jpg).toString() : QString();
}

bool IncipitEdicao::abrirVideo(const QString &arquivo) const
{
	const QFileInfo fi(arquivo);
	const QString ext = fi.suffix().toLower();
	if(!fi.isFile() || !(ext == QStringLiteral("mp4") || ext == QStringLiteral("mkv") || ext == QStringLiteral("mov"))
		|| !dentroDe(arquivo, ClipRecorder::instance()->clipsDir()))
		return false;
	return QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absoluteFilePath()));
}

bool IncipitEdicao::abrirPasta(const QString &pasta) const
{
	const QFileInfo fi(pasta);
	const QString raiz = QDir(ClipRecorder::instance()->clipsDir()).canonicalPath();
	if(!fi.isDir() || (fi.canonicalFilePath().compare(raiz, Qt::CaseInsensitive) != 0 && !dentroDe(pasta, raiz)))
		return false;
	return QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absoluteFilePath()));
}

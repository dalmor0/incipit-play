// Incipit Play · clipes: guarda os últimos segundos do Remote Play (vídeo e áudio como chegam do console, sem
// recodificar) e grava um .mp4 quando a pessoa aperta o atalho. Também corta o fim dos arquivos da placa de
// captura (aba Switch) e manda o Replay Buffer do OBS salvar.
#ifndef INCIPIT_CLIPRECORDER_H
#define INCIPIT_CLIPRECORDER_H

#include <QObject>
#include <QMutex>
#include <QByteArray>
#include <QElapsedTimer>
#include <QVariantList>
#include <QAbstractNativeEventFilter>
#include <deque>

class QWebSocket;

class ClipRecorder : public QObject, public QAbstractNativeEventFilter
{
	Q_OBJECT
	Q_PROPERTY(bool streaming READ streaming NOTIFY streamingChanged)
	Q_PROPERTY(bool hotkeyActive READ hotkeyActive NOTIFY hotkeyChanged)
	Q_PROPERTY(QString hotkeyText READ hotkeyText NOTIFY hotkeyChanged)
	Q_PROPERTY(int bufferMegabytes READ bufferMegabytes NOTIFY bufferChanged)

public:
	static ClipRecorder *instance();

	// chamado pelo StreamSession (thread da sessão)
	void beginStream(bool hevc, const QString &title, int width, int height);
	void endStream();
	void pushVideo(const uint8_t *buf, size_t size);
	void setAudioFormat(int channels, int rate);
	void pushAudio(const uint8_t *buf, size_t size);
	bool wantsKeyframe();      // true quando faz mais de 8 s sem quadro-chave (o StreamSession pede um ao console)

	bool streaming() const { return is_streaming; }
	bool hotkeyActive() const { return hotkey_registered; }
	QString hotkeyText() const { return hotkey_text; }
	int bufferMegabytes() const { return int(buffer_bytes / (1024 * 1024)); }

	// para a interface
	Q_INVOKABLE int seconds() const { return clip_seconds; }
	Q_INVOKABLE void setSeconds(int s);
	Q_INVOKABLE bool setHotkey(const QString &combo);         // "Alt+F10", "Alt+F9", "Ctrl+Alt+S", "F8"
	Q_INVOKABLE QString clipsDir() const;
	Q_INVOKABLE void setClipsDir(const QString &dir);
	Q_INVOKABLE QString saveNow();                            // salva o fim do Remote Play; caminho ou vazio
	Q_INVOKABLE QString saveTailOfFiles(const QStringList &files, int seconds, const QString &title);
	Q_INVOKABLE QVariantList library() const;                 // sessões (pastas), a atual primeiro, cada uma com seus clipes
	Q_INVOKABLE QString startSession(const QString &title);   // pasta "<data> <jogo>" desta transmissão
	Q_INVOKABLE bool trash(const QString &path);              // vai pra Lixeira, não apaga de vez
	Q_INVOKABLE QString sendToEditing(const QString &path, const QString &inbox, const QString &pedido);
	Q_INVOKABLE QString defaultEditingInbox() const;
	Q_INVOKABLE QString tempCaptureDir() const;
	Q_INVOKABLE bool removeTemp(const QString &path);
	Q_INVOKABLE void setObs(bool enabled, int port, const QString &password);
	Q_INVOKABLE void testObs();

	bool nativeEventFilter(const QByteArray &type, void *message, qintptr *result) override;

signals:
	void streamingChanged();
	void hotkeyChanged();
	void bufferChanged();
	void clipRequested();                                     // o atalho foi apertado (a aba Switch escuta)
	void clipSaved(const QString &path, const QString &title, double seconds);
	void clipFailed(const QString &reason);
	void libraryChanged();
	void obsStatus(const QString &text, bool ok);

private:
	explicit ClipRecorder(QObject *parent = nullptr);
	void onHotkey();
	void trimLocked();
	void writeSidecar(const QString &mp4, const QString &title, double seconds);
	void makeThumbnail(const QString &mp4);
	void obsSave();

	struct Packet { QByteArray data; qint64 t_us; bool video; bool key; };

	mutable QMutex mutex;
	std::deque<Packet> ring;
	qint64 buffer_bytes = 0;
	QElapsedTimer clock;
	qint64 last_key_us = -1;
	QByteArray params_latest;   // VPS/SPS/PPS mais recentes: o PS5 só manda no começo da sessão
	qint64 last_key_request_us = -1;
	bool is_streaming = false;
	bool hevc = true;
	int video_w = 1920, video_h = 1080;
	int audio_channels = 2;
	int audio_rate = 48000;
	QString title;
	int clip_seconds = 90;
	QString clips_dir;
	QString session_dir;
	QString session_title;

	bool hotkey_registered = false;
	QString hotkey_text;
	unsigned hotkey_mod = 0, hotkey_vk = 0;

	bool obs_enabled = false;
	int obs_port = 4455;
	QString obs_password;
	QWebSocket *obs_socket = nullptr;
};

#endif

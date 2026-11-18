// Incipit Play · edição automática dos clipes ("Mandar pra edição").
// Baixa o pacote de edição na primeira vez (endereço e SHA-256 fixos aqui), roda o clipador (edicao/clipador, Python)
// num Job do Windows com prioridade baixa e lê o andamento pela saída dele, uma linha JSON por evento.
// Nunca disputa a máquina com a transmissão: com o jogo aberto, o pedido espera na fila; se o jogo abrir no meio,
// a edição cai pra prioridade ociosa. Tudo roda neste PC; nada é mandado pra fora.
#ifndef INCIPIT_EDICAO_H
#define INCIPIT_EDICAO_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QStringList>
#include <QPointer>
#include <QCryptographicHash>

class QProcess;
class QNetworkAccessManager;
class QNetworkReply;
class QFile;

class IncipitEdicao : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QString estado READ estado NOTIFY mudou)          // livre | baixando | fila | editando | pronto | erro
	Q_PROPERTY(double pct READ pct NOTIFY mudou)                 // 0 a 100
	Q_PROPERTY(QString etapa READ etapa NOTIFY mudou)            // texto da etapa, já pra pessoa
	Q_PROPERTY(QString clipe READ clipe NOTIFY mudou)            // clipe sendo editado
	Q_PROPERTY(QVariantMap resultado READ resultado NOTIFY mudou)
	Q_PROPERTY(QString motivo READ motivo NOTIFY mudou)          // por que deu erro, em uma linha
	Q_PROPERTY(bool cancelado READ cancelado NOTIFY mudou)
	Q_PROPERTY(bool pacotePronto READ pacotePronto NOTIFY mudou)
	Q_PROPERTY(bool travada READ travada CONSTANT)              // trava de plano (desligada; ver edicao/travaPlano)

public:
	static IncipitEdicao *instance();

	QString estado() const { return m_estado; }
	double pct() const { return m_pct; }
	QString etapa() const { return m_etapa; }
	QString clipe() const { return m_clipe; }
	QVariantMap resultado() const { return m_resultado; }
	QString motivo() const { return m_motivo; }
	bool cancelado() const { return m_cancelado; }
	bool pacotePronto() const;
	bool travada() const;

	// opcoes: pedido, layout (auto|camera|centro|desfocado), estilo, semLegenda, titulo, zoom (-1 = padrão),
	//         inicio/fim (segundos; -1 = o clipador escolhe), camera ([x,y,w,h] de 0 a 1), musica (pasta)
	Q_INVOKABLE bool editar(const QString &clipe, const QVariantMap &opcoes);
	Q_INVOKABLE void cancelar();
	Q_INVOKABLE void editarAgora();                              // sai da fila mesmo com o jogo aberto (prioridade ociosa)
	Q_INVOKABLE void fechar();                                   // volta pro "livre" depois de ver o resultado ou o erro
	Q_INVOKABLE QString pastaSaida() const;
	Q_INVOKABLE void mostrarNaPasta(const QString &arquivo) const;
	Q_INVOKABLE QVariantList editados(int limite = 24) const;    // os .json dos editados, do mais novo pro mais velho
	Q_INVOKABLE QString editadoDe(const QString &clipe) const;   // o editado mais novo de um clipe, ou vazio
	Q_INVOKABLE bool apagarEditado(const QString &arquivo);      // vai pra Lixeira
	Q_INVOKABLE QString quadroDoClipe(const QString &clipe) const; // miniatura 16:9 do clipe (pra marcar a câmera)
	// abrir vídeo e pasta sempre por aqui (QUrl::fromLocalFile), nunca colando "file:///" + nome no QML: um nome
	// de arquivo com %5C e %00 virava outro caminho e o Windows abria outro programa (achado A1 da segurança)
	Q_INVOKABLE bool abrirVideo(const QString &arquivo) const;
	Q_INVOKABLE bool abrirPasta(const QString &pasta) const;

signals:
	void mudou();
	void terminou(bool ok);
	void editadosMudaram();

private:
	explicit IncipitEdicao(QObject *parent = nullptr);
	void definir(const QString &estado, double pct, const QString &etapa);
	void baixarPacote();
	void instalarPacote(const QString &zip);
	void comecar();
	void lerSaida();
	void falhar(const QString &motivo);
	void ajustarPrioridade();
	void encerrarProcesso();
	QString raizPacote() const;
	QString pythonDoPacote() const;
	void registrar(const QString &linha) const;

	QString m_estado = QStringLiteral("livre");
	double m_pct = 0;
	QString m_etapa;
	QString m_clipe;
	QVariantMap m_opcoes;
	QVariantMap m_resultado;
	QString m_motivo;
	bool m_cancelado = false;
	bool m_furouFila = false;
	bool m_recebeuFim = false;

	QProcess *m_proc = nullptr;
	void *m_job = nullptr;
	QByteArray m_buffer;

	QNetworkAccessManager *m_rede = nullptr;
	QPointer<QNetworkReply> m_download;
	QFile *m_arquivo = nullptr;
	QCryptographicHash m_hash{QCryptographicHash::Sha256};
	qint64 m_baixado = 0;
};

#endif

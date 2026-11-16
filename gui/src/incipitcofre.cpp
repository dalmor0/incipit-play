// Incipit Play · cofre. Ver incipitcofre.h.
#include "incipitcofre.h"

#include <QByteArray>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dpapi.h>
#endif

static const char *PREFIXO = "dpapi1:";
static const char ENTROPIA[] = "Incipit Play";

QString IncipitCofre::Proteger(const QString &texto)
{
	if(texto.isEmpty())
		return QString();
#ifdef Q_OS_WIN
	QByteArray puro = texto.toUtf8();
	DATA_BLOB entrada{DWORD(puro.size()), reinterpret_cast<BYTE *>(puro.data())};
	DATA_BLOB entropia{DWORD(sizeof(ENTROPIA) - 1), reinterpret_cast<BYTE *>(const_cast<char *>(ENTROPIA))};
	DATA_BLOB saida{0, nullptr};
	if(!CryptProtectData(&entrada, L"Incipit Play", &entropia, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &saida))
		return texto;   // sem DPAPI (raro): guarda como veio, pra não perder o login
	const QByteArray cifrado(reinterpret_cast<const char *>(saida.pbData), int(saida.cbData));
	SecureZeroMemory(puro.data(), size_t(puro.size()));
	LocalFree(saida.pbData);
	return QString::fromLatin1(PREFIXO) + QString::fromLatin1(cifrado.toBase64());
#else
	return texto;
#endif
}

QString IncipitCofre::Abrir(const QString &guardado, bool *estava_aberto)
{
	if(estava_aberto)
		*estava_aberto = false;
	if(guardado.isEmpty())
		return QString();
	if(!guardado.startsWith(QLatin1String(PREFIXO)))
	{
		if(estava_aberto)
			*estava_aberto = true;
		return guardado;
	}
#ifdef Q_OS_WIN
	QByteArray cifrado = QByteArray::fromBase64(guardado.mid(int(strlen(PREFIXO))).toLatin1());
	DATA_BLOB entrada{DWORD(cifrado.size()), reinterpret_cast<BYTE *>(cifrado.data())};
	DATA_BLOB entropia{DWORD(sizeof(ENTROPIA) - 1), reinterpret_cast<BYTE *>(const_cast<char *>(ENTROPIA))};
	DATA_BLOB saida{0, nullptr};
	if(!CryptUnprotectData(&entrada, nullptr, &entropia, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &saida))
		return QString();   // outra conta ou outro PC: o login precisa ser feito de novo
	const QString texto = QString::fromUtf8(reinterpret_cast<const char *>(saida.pbData), int(saida.cbData));
	SecureZeroMemory(saida.pbData, saida.cbData);
	LocalFree(saida.pbData);
	return texto;
#else
	return QString();
#endif
}

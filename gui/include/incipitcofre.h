// Incipit Play · cofre: cifra segredos (tokens da PSN, senha do OBS) com o DPAPI do Windows antes de ir pro registro.
// Só a mesma conta do Windows, neste PC, consegue abrir. Fora do Windows, guarda como veio.
#ifndef INCIPIT_COFRE_H
#define INCIPIT_COFRE_H

#include <QString>

namespace IncipitCofre
{
	// "dpapi1:<base64>"; texto vazio fica vazio
	QString Proteger(const QString &texto);
	// devolve o texto puro; *estava_aberto = true quando o valor guardado ainda não era cifrado (pra migrar)
	QString Abrir(const QString &guardado, bool *estava_aberto = nullptr);
}

#endif

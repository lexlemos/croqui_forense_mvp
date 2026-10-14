# Keep-Alive Wakelock During Sync

## Status
Accepted

## Context
Em plantões de necropsia, laudos com dezenas de fotografias periciais sob rede celular (3G/4G rural) podem levar de 2 a 5 minutos para sincronizar. Se o tablet do perito apagar a tela por inatividade (timeout padrão de 30-60s), o Android entra em Doze Mode, suspendendo a thread do Flutter e cortando conexões de soquete TCP no meio do upload de mídias.

## Decision
Adotamos a estratégia híbrida de **Keep-Alive Wakelock transitório**:
1. O `SyncProvider` adquire o wakelock (`wakelock_plus`) ao iniciar o ciclo de sincronização e obrigatoriamente o libera em bloco `finally`.
2. As chamadas ao wakelock são encapsuladas em um helper seguro (`SafeWakelock`) para falhar silenciosamente sem quebrar a execução em testes unitários ou ambientes Desktop (Windows).
3. Mantemos a garantia de **Atomic Media Upload**: como o `SyncService` persiste o hash e status de envio foto a foto, caso ocorra qualquer interrupção não prevista (bateria esgotada), o próximo ciclo retoma do ponto exato onde parou.

## Considered Options
- **Foreground Service Nativo Persistente (`flutter_foreground_task`)**: Rejeitado por exigir permissões invasivas de sistema (`POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`), ícone permanente na bandeja e complexidade desnecessária para operações disparadas pelo usuário em primeiro plano.
- **Wakelock puro acoplado no domínio (`SyncService`)**: Rejeitado por violar a Clean Architecture ao injetar dependência de plugins de tela/plataforma na camada de negócio.

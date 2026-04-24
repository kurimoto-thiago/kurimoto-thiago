'use strict';
// PATCH: Adicione estas linhas no final do src/app.js
// para que o mesmo arquivo sirva EC2 (listen) e Lambda (export sem listen)
//
// Substitua o bloco "async function start()" atual por:

/*
async function start() {
  try {
    await pgTest();
    await redisTest();
    app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Servidor iniciado na porta ${PORT}`, {
        env: process.env.NODE_ENV || 'development',
      });
    });
  } catch (err) {
    logger.error('Falha ao iniciar servidor', { error: err.message });
    process.exit(1);
  }
}

// Só faz listen quando executado diretamente (EC2 / Docker)
// No Lambda, src/lambda.js importa o app sem chamar start()
if (require.main === module) {
  start();
}

module.exports = app;
*/

// ecosystem.config.js — PM2
// Usado tanto no EC2 direto quanto no user_data
module.exports = {
  apps: [
    {
      name:             'lanchonete-api',
      script:           'src/app.js',
      instances:        'max',       // cluster: 1 proc por vCPU
      exec_mode:        'cluster',
      max_memory_restart: '400M',
      watch:            false,
      env_production: {
        NODE_ENV: 'production',
      },
      error_file:       'logs/err.log',
      out_file:         'logs/out.log',
      merge_logs:       true,
      log_date_format:  'YYYY-MM-DD HH:mm:ss Z',
      // Graceful shutdown — aguarda conexões ativas
      kill_timeout:     5000,
      listen_timeout:   8000,
      // Reinicia automático em crash
      autorestart:      true,
      restart_delay:    3000,
      max_restarts:     10,
    },
  ],
};

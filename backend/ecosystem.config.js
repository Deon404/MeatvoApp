const instances = Number(process.env.PM2_INSTANCES || 1);
const execMode = instances > 1 ? 'cluster' : 'fork';

module.exports = {
  apps: [
    {
      name: 'meatvo-backend',
      script: 'index.js',
      cwd: __dirname,
      instances,
      exec_mode: execMode,
      autorestart: true,
      watch: false,
      max_memory_restart: process.env.PM2_MAX_MEMORY || '512M',
      kill_timeout: 15000,
      listen_timeout: 10000,
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      env: {
        NODE_ENV: 'development',
      },
      env_production: {
        NODE_ENV: 'production',
      },
    },
  ],
};

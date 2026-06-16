# Meatvo — Infrastructure & DevOps

**Version:** 1.0  
**Date:** June 12, 2026  
**Owner:** DevOps Team

---

## 1. Infrastructure Overview

### 1.1 Deployment Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      PRODUCTION ARCHITECTURE                     │
└──────────────────────────────────────────────────────────────────┘

Internet
   │
   ▼
┌──────────────────────────────────────────────────────────────────┐
│                        CLOUDFLARE                                │
│  • DNS Management        • DDoS Protection                       │
│  • SSL/TLS Termination   • WAF (Web Application Firewall)        │
│  • CDN (Static Assets)   • Edge Caching                          │
└──────────────────────────────────────────────────────────────────┘
   │
   ▼
┌──────────────────────────────────────────────────────────────────┐
│                    UBUNTU VPS (Digital Ocean / AWS EC2)          │
│  Location: Mumbai, India (ap-south-1)                            │
│  Specs: 8 vCPU, 16GB RAM, 200GB SSD                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    NGINX (Reverse Proxy)               │    │
│  │  • Load Balancing       • SSL Termination (Let's      │    │
│  │  • HTTP/2, WebSocket    Encrypt)                       │    │
│  │  • Rate Limiting        • Static File Serving          │    │
│  └────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              DOCKER COMPOSE STACK                      │    │
│  ├────────────────────────────────────────────────────────┤    │
│  │                                                        │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  NestJS Backend (Container: meatvo-api)     │     │    │
│  │  │  • Port: 8080 (internal)                    │     │    │
│  │  │  • Replicas: 2 (for load balancing)         │     │    │
│  │  │  • Health checks: /health endpoint          │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │                                                        │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  PostgreSQL 15 (Container: meatvo-db)       │     │    │
│  │  │  • Port: 5432 (internal)                    │     │    │
│  │  │  • Volume: /var/lib/postgresql/data         │     │    │
│  │  │  • Backup: Daily to Cloudflare R2           │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │                                                        │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  Redis 7 (Container: meatvo-cache)          │     │    │
│  │  │  • Port: 6379 (internal)                    │     │    │
│  │  │  • Persistence: AOF + RDB                    │     │    │
│  │  │  • Max Memory: 2GB (LRU eviction)           │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │                                                        │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  Grafana (Container: grafana)               │     │    │
│  │  │  • Port: 3000 (internal)                    │     │    │
│  │  │  • Dashboards: API metrics, DB metrics       │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │                                                        │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  Prometheus (Container: prometheus)          │     │    │
│  │  │  • Port: 9090 (internal)                    │     │    │
│  │  │  • Scrapes metrics from NestJS, DB, Redis    │     │    │
│  │  └──────────────────────────────────────────────┘     │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Infrastructure Components

| Component | Technology | Purpose | Scalability |
|-----------|-----------|---------|-------------|
| **Edge CDN** | Cloudflare | Static assets, DDoS protection, WAF | Global edge network |
| **Compute** | Ubuntu VPS 22.04 LTS | Application hosting | Vertical scaling (upgrade CPU/RAM) |
| **Reverse Proxy** | Nginx 1.24+ | Load balancing, SSL termination | Horizontal scaling (multiple instances) |
| **Backend** | NestJS + Node.js 20 | API server | Horizontal scaling (Docker replicas) |
| **Database** | PostgreSQL 15 | Transactional data | Vertical scaling → Read replicas → Sharding |
| **Cache** | Redis 7 | Session, cache, pub/sub | Vertical scaling → Redis Cluster |
| **Container Runtime** | Docker 24.x + Docker Compose | Containerization | Native orchestration support |
| **Storage** | Cloudflare R2 | Object storage (images, backups) | Unlimited (S3-compatible) |
| **Monitoring** | Prometheus + Grafana | Metrics & dashboards | Standalone or cloud-hosted |
| **CI/CD** | GitHub Actions | Automated deployment | Cloud-hosted |

---

## 2. Server Configuration

### 2.1 VPS Specifications

**Current (MVP — 10K users):**
```
Provider: DigitalOcean / AWS EC2
Region: Mumbai (ap-south-1)
Instance Type: 
  - DigitalOcean: Premium Intel (8 vCPU, 16GB RAM)
  - AWS: t3.xlarge (4 vCPU, 16GB RAM)
Disk: 200GB SSD
OS: Ubuntu 22.04 LTS
Network: 5TB transfer/month
Cost: ~$100-150/month
```

**Scaling Path:**
```
Phase 1 (10K users):   8 vCPU, 16GB RAM
Phase 2 (50K users):   16 vCPU, 32GB RAM
Phase 3 (100K users):  Multiple servers (load balanced)
```

### 2.2 Docker Compose Configuration

**File: `docker-compose.yml`**
```yaml
version: '3.9'

services:
  api:
    image: meatvo/backend:latest
    container_name: meatvo-api
    restart: always
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    networks:
      - meatvo-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G

  postgres:
    image: postgres:15-alpine
    container_name: meatvo-db
    restart: always
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_NAME}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "5432:5432"
    networks:
      - meatvo-network
    command: >
      postgres 
      -c max_connections=200 
      -c shared_buffers=1GB 
      -c effective_cache_size=4GB 
      -c maintenance_work_mem=512MB 
      -c checkpoint_completion_target=0.9 
      -c wal_buffers=16MB 
      -c default_statistics_target=100 
      -c random_page_cost=1.1 
      -c effective_io_concurrency=200

  redis:
    image: redis:7-alpine
    container_name: meatvo-cache
    restart: always
    command: >
      redis-server 
      --requirepass ${REDIS_PASSWORD} 
      --maxmemory 2gb 
      --maxmemory-policy allkeys-lru 
      --appendonly yes
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
    networks:
      - meatvo-network

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - meatvo-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana-data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - meatvo-network
    depends_on:
      - prometheus

networks:
  meatvo-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  prometheus-data:
  grafana-data:
```

### 2.3 Nginx Configuration

**File: `/etc/nginx/sites-available/meatvo`**
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/m;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=20r/m;

# Upstream backend (load balanced)
upstream meatvo_backend {
    least_conn;
    server localhost:8080 max_fails=3 fail_timeout=30s;
    server localhost:8081 max_fails=3 fail_timeout=30s;
}

# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name api.meatvo.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.meatvo.com;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/api.meatvo.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.meatvo.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript;

    # Rate limiting
    location /api/auth/ {
        limit_req zone=auth_limit burst=5 nodelay;
        proxy_pass http://meatvo_backend;
        include /etc/nginx/proxy_params;
    }

    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        proxy_pass http://meatvo_backend;
        include /etc/nginx/proxy_params;
    }

    # WebSocket support
    location /socket.io/ {
        proxy_pass http://meatvo_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check
    location /health {
        proxy_pass http://meatvo_backend/health;
        access_log off;
    }
}
```

---

## 3. CI/CD Pipeline

### 3.1 GitHub Actions Workflow

**File: `.github/workflows/deploy-production.yml`**
```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: ./backend
        run: npm ci

      - name: Run tests
        working-directory: ./backend
        run: npm run test

      - name: Run security audit
        working-directory: ./backend
        run: npm audit --audit-level=high

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build Docker image
        working-directory: ./backend
        run: |
          docker build -t meatvo/backend:${{ github.sha }} .
          docker tag meatvo/backend:${{ github.sha }} meatvo/backend:latest

      - name: Push Docker image
        run: |
          docker push meatvo/backend:${{ github.sha }}
          docker push meatvo/backend:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /opt/meatvo
            docker-compose pull
            docker-compose up -d --remove-orphans
            docker-compose exec -T api npm run migration:run
            docker system prune -f

      - name: Health check
        run: |
          sleep 30
          curl -f https://api.meatvo.com/health || exit 1

      - name: Notify Slack
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Production deployment: ${{ job.status }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### 3.2 Deployment Process

```
┌──────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT WORKFLOW                           │
└──────────────────────────────────────────────────────────────────┘

1. Developer pushes to `main` branch
   └─> GitHub Actions triggered

2. Run Tests (Jest)
   ├─> Unit tests
   ├─> Integration tests
   └─> E2E tests

3. Security Audit
   ├─> npm audit (dependency vulnerabilities)
   ├─> ESLint (code quality)
   └─> SonarQube scan (optional)

4. Build Docker Image
   ├─> Multi-stage build (node:20-alpine)
   ├─> Tag with commit SHA + 'latest'
   └─> Push to Docker Hub

5. Deploy to Production VPS
   ├─> SSH into server
   ├─> Pull latest image: docker-compose pull
   ├─> Stop old containers: docker-compose down
   ├─> Start new containers: docker-compose up -d
   ├─> Run database migrations: npm run migration:run
   └─> Clean up: docker system prune

6. Health Check
   ├─> Wait 30 seconds (warm-up)
   ├─> Curl /health endpoint
   └─> Verify 200 OK response

7. Post-Deployment
   ├─> Notify team (Slack)
   ├─> Monitor logs (5 minutes)
   └─> Rollback if errors detected
```

### 3.3 Rollback Strategy

**Automated Rollback Trigger:**
- Health check fails after deployment
- Error rate >5% in first 5 minutes
- Manual trigger by DevOps team

**Rollback Steps:**
```bash
# Quick rollback to previous image
cd /opt/meatvo
docker-compose down
docker-compose up -d --scale api=2 meatvo/backend:<previous_sha>
docker-compose exec api npm run migration:revert

# Verify
curl https://api.meatvo.com/health
```

---

## 4. Backup & Disaster Recovery

### 4.1 Database Backup Strategy

**Automated Backups (Cron):**
```bash
# /etc/cron.d/meatvo-backup

# Full backup daily at 2 AM UTC
0 2 * * * meatvo /opt/meatvo/scripts/backup-db.sh

# Incremental backup every 6 hours
0 */6 * * * meatvo /opt/meatvo/scripts/backup-db-incremental.sh
```

**Backup Script (`backup-db.sh`):**
```bash
#!/bin/bash
set -e

BACKUP_DIR="/var/backups/meatvo"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="meatvo_db_${TIMESTAMP}.sql.gz"

# Create backup
docker exec meatvo-db pg_dump -U ${DB_USER} ${DB_NAME} | gzip > ${BACKUP_DIR}/${BACKUP_FILE}

# Encrypt backup
openssl enc -aes-256-cbc -salt -in ${BACKUP_DIR}/${BACKUP_FILE} \
  -out ${BACKUP_DIR}/${BACKUP_FILE}.enc -pass pass:${BACKUP_PASSWORD}

# Upload to Cloudflare R2
aws s3 cp ${BACKUP_DIR}/${BACKUP_FILE}.enc \
  s3://meatvo-backups/database/${BACKUP_FILE}.enc \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com

# Cleanup local backup (keep last 7 days)
find ${BACKUP_DIR} -name "meatvo_db_*.sql.gz*" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}"
```

### 4.2 Recovery Procedures

**Scenario 1: Database Corruption**
```bash
# Stop application
docker-compose stop api

# Download latest backup from R2
aws s3 cp s3://meatvo-backups/database/meatvo_db_20260612_020000.sql.gz.enc \
  /tmp/restore.sql.gz.enc \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com

# Decrypt backup
openssl enc -d -aes-256-cbc -in /tmp/restore.sql.gz.enc \
  -out /tmp/restore.sql.gz -pass pass:${BACKUP_PASSWORD}

# Restore database
gunzip < /tmp/restore.sql.gz | docker exec -i meatvo-db psql -U ${DB_USER} ${DB_NAME}

# Restart application
docker-compose start api

# Verify
curl https://api.meatvo.com/health
```

**Scenario 2: Complete Server Failure**
```bash
# Provision new VPS (Ubuntu 22.04)
# Install Docker + Docker Compose
curl -fsSL https://get.docker.com | sh

# Clone repository
git clone https://github.com/meatvo/backend.git /opt/meatvo
cd /opt/meatvo

# Restore .env file from secure vault (AWS Secrets Manager / 1Password)
# Download latest database backup from R2 (as above)
# Start services
docker-compose up -d

# Restore database (as above)
# Update DNS to point to new server IP (Cloudflare)
# Verify
```

**Recovery Time Objective (RTO):** 2 hours  
**Recovery Point Objective (RPO):** 1 hour (based on 6-hour incremental backups)

---

## 5. Monitoring & Observability

### 5.1 Prometheus Metrics

**Backend Metrics (NestJS + Prometheus client):**
```typescript
// metrics.service.ts
import { Counter, Histogram, Gauge } from 'prom-client';

// HTTP requests
this.httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Request duration
this.httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5]
});

// Active orders
this.activeOrders = new Gauge({
  name: 'active_orders_total',
  help: 'Total active orders',
  labelNames: ['status']
});

// Database connections
this.dbConnections = new Gauge({
  name: 'db_connections_active',
  help: 'Active database connections'
});
```

**Prometheus Configuration (`prometheus.yml`):**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'meatvo-api'
    static_configs:
      - targets: ['api:8080']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### 5.2 Grafana Dashboards

**Dashboard 1: API Performance**
- Requests per second (by endpoint)
- Response time (P50, P95, P99)
- Error rate (4xx, 5xx)
- Active connections

**Dashboard 2: Database Metrics**
- Query performance (slow queries >500ms)
- Connection pool usage
- Cache hit ratio
- Table sizes

**Dashboard 3: Business Metrics**
- Orders per hour
- Revenue (hourly, daily)
- Active users
- Order status distribution

**Dashboard 4: System Resources**
- CPU usage
- Memory usage
- Disk I/O
- Network throughput

### 5.3 Alerting Rules

**Critical Alerts (PagerDuty):**
- API error rate >5% for 5 minutes
- Database connection pool >90% for 2 minutes
- Disk usage >90%
- Server down (health check fails for 3 consecutive checks)

**High Alerts (Slack):**
- API P95 response time >500ms for 10 minutes
- Order processing delay >2 minutes
- Redis memory >80%

**Medium Alerts (Email):**
- Slow queries >1s detected
- Backup failure
- SSL certificate expiry <7 days

---

## 6. Scaling Strategy

### 6.1 Vertical Scaling (Phase 1)

**Current (10K users):**
- VPS: 8 vCPU, 16GB RAM
- Database: Same server
- Redis: Same server

**Scaled (50K users):**
- VPS: 16 vCPU, 32GB RAM, 500GB SSD
- Database: Dedicated VPS (8 vCPU, 16GB RAM)
- Redis: Dedicated VPS (4 vCPU, 8GB RAM)

**Cost Estimate:**
- Application VPS: $200/month
- Database VPS: $150/month
- Redis VPS: $100/month
- **Total: $450/month**

### 6.2 Horizontal Scaling (Phase 2)

```
┌──────────────────────────────────────────────────────────────────┐
│                  HORIZONTAL SCALING ARCHITECTURE                 │
└──────────────────────────────────────────────────────────────────┘

Load Balancer (Nginx / HAProxy)
         │
         ├──────────────────┬──────────────────┬──────────────────┐
         ▼                  ▼                  ▼                  ▼
   API Server 1       API Server 2       API Server 3       API Server N
   (8 vCPU, 16GB)     (8 vCPU, 16GB)     (8 vCPU, 16GB)     (Auto-scaled)
         │                  │                  │                  │
         └──────────────────┴──────────────────┴──────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
          PostgreSQL Master                  Redis Cluster
          (Read/Write)                       (3 nodes)
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
    Read Replica 1      Read Replica 2
    (Read-only)         (Read-only)
```

**Configuration:**
- Load Balancer: Nginx (round-robin, health checks)
- API Servers: 3+ instances (Docker containers, auto-scaled)
- Database: Master + 2 Read Replicas (for read-heavy queries)
- Redis: Cluster mode (3 nodes, replication)

**Cost Estimate (100K users):**
- Load Balancer: $50/month
- API Servers (3x): $600/month
- Database (1 master + 2 replicas): $600/month
- Redis Cluster (3 nodes): $300/month
- **Total: $1,550/month**

### 6.3 Cloud Migration (Phase 3)

**AWS Architecture (Future):**
```
Route 53 (DNS)
   │
   ▼
CloudFront (CDN)
   │
   ▼
Application Load Balancer
   │
   ├──────────────────┐
   ▼                  ▼
ECS Fargate       ECS Fargate
(API Container)   (API Container)
   │
   ▼
RDS PostgreSQL (Multi-AZ)
   │
   ▼
ElastiCache Redis (Cluster mode)
```

**Benefits:**
- Auto-scaling (based on CPU, memory, request count)
- Multi-region deployment (low latency)
- Managed services (RDS, ElastiCache)
- Built-in backups, failover

**Cost Estimate (100K users on AWS):**
- ECS Fargate (3 tasks): $150/month
- RDS PostgreSQL (db.r6g.xlarge): $350/month
- ElastiCache Redis (cache.r6g.large): $200/month
- CloudFront + S3: $100/month
- **Total: $800/month** (comparable to self-managed, less operational overhead)

---

## 7. Security Hardening

### 7.1 Server Hardening Checklist

**OS Security:**
- [x] Firewall enabled (UFW): Allow 22, 80, 443 only
- [x] SSH key-only authentication (password auth disabled)
- [x] Fail2Ban configured (ban after 5 failed SSH attempts)
- [x] Automatic security updates (unattended-upgrades)
- [x] Non-root user for application (meatvo user)

**Docker Security:**
- [x] Run containers as non-root user
- [x] Resource limits (CPU, memory)
- [x] Read-only root filesystem (where possible)
- [x] Vulnerability scanning (Trivy)

**Network Security:**
- [x] Private Docker network (isolated)
- [x] Database/Redis not exposed to public internet
- [x] SSL/TLS for all external connections
- [x] Cloudflare WAF enabled

### 7.2 SSL/TLS Configuration

**Let's Encrypt Auto-Renewal:**
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d api.meatvo.com

# Auto-renewal (cron)
0 12 * * * /usr/bin/certbot renew --quiet
```

**SSL Labs Grade:** A+ (target)

---

## 8. Cost Breakdown

### 8.1 Current Infrastructure Costs (Monthly)

| Component | Provider | Cost |
|-----------|----------|------|
| VPS (8 vCPU, 16GB) | DigitalOcean | $120 |
| Cloudflare Pro | Cloudflare | $20 |
| Cloudflare R2 (Storage) | Cloudflare | $15 (100GB) |
| Domain (.com) | Namecheap | $1 |
| SMS Gateway (OTP) | MSG91 | $50 (10K OTPs) |
| Payment Gateway | Razorpay | 2% per transaction |
| Firebase FCM | Google | Free (up to 1M messages/day) |
| Google Maps API | Google | $200 (50K requests) |
| GitHub (private repo) | GitHub | $4 (Team plan) |
| **Total Fixed** | | **$410/month** |

### 8.2 Variable Costs

| Component | Unit Cost | Monthly Estimate (10K users) |
|-----------|-----------|------------------------------|
| SMS (OTP) | ₹0.15/SMS | ₹1,500 (~10K OTPs) → $18 |
| Payment Gateway (Razorpay) | 2% + ₹3 per transaction | ₹40,000 (10K orders @ ₹400 avg) → $480 |
| Google Maps (Geocoding) | $5 per 1000 requests | $50 (10K requests) |
| Bandwidth (Cloudflare) | Free | $0 |
| **Total Variable** | | **~$550/month** |

**Total Operating Cost (10K users):** $960/month (~₹80,000)

### 8.3 Scaling Cost Projections

| Users | Infrastructure | Total Monthly Cost |
|-------|----------------|--------------------|
| 10K   | Single VPS | $960 |
| 50K   | Multi-VPS | $2,500 |
| 100K  | Horizontal scaling | $5,000 |
| 500K  | Cloud (AWS/GCP) | $15,000 |
| 1M+   | Multi-region cloud | $30,000+ |

---

## 9. Disaster Recovery Plan

### 9.1 Disaster Scenarios & Mitigation

| Scenario | Impact | RTO | RPO | Mitigation |
|----------|--------|-----|-----|------------|
| Database crash | High | 30 min | 1 hour | Restore from latest backup, automate failover |
| Server crash | Critical | 1 hour | 1 hour | Rebuild from backup, DNS failover to standby |
| DDoS attack | High | 0 min | 0 min | Cloudflare absorbs attack, auto-scale if needed |
| Data corruption | Critical | 2 hours | 6 hours | Restore from incremental backup |
| Code deployment failure | Medium | 5 min | 0 min | Rollback to previous Docker image |
| SSL certificate expiry | Medium | 1 hour | 0 min | Auto-renewal, monitoring alerts 7 days prior |

### 9.2 Business Continuity

**Failover Strategy:**
- Primary VPS (Mumbai): Active
- Secondary VPS (Bangalore): Standby (cold standby, manual failover)
- DNS TTL: 300 seconds (quick failover)

**Data Replication:**
- Database: Daily backups to Cloudflare R2 (Mumbai + US regions)
- Application: Docker images on Docker Hub (replicated globally)
- Secrets: AWS Secrets Manager + encrypted local backup

**Communication Plan:**
- Incident detected → Alert DevOps team (PagerDuty)
- CTO notified for critical incidents
- Customer communication: Email + in-app banner
- Status page: status.meatvo.com (hosted on separate server)

---

## 10. Performance Optimization

### 10.1 Database Optimization

**Indexes:**
- Composite indexes on frequently queried columns
- Partial indexes for filtered queries
- GIN indexes for full-text search

**Query Optimization:**
- N+1 query elimination (eager loading)
- Connection pooling (max 100 connections)
- Prepared statements (parameterized queries)

**Partitioning (Future):**
- Partition orders table by month (for high volume)

### 10.2 Caching Strategy

**Redis Caching:**
- Product catalog: TTL 5 minutes
- Category tree: TTL 10 minutes
- User sessions: TTL = session lifetime
- API responses (read-only): TTL 1 minute

**CDN Caching (Cloudflare):**
- Static assets (images): TTL 7 days
- Product images: TTL 1 day

### 10.3 API Optimization

**Response Time Targets:**
- P50: <100ms
- P95: <200ms
- P99: <500ms

**Optimization Techniques:**
- Pagination (limit/offset)
- Field selection (GraphQL-style)
- Compression (Gzip, Brotli)
- HTTP/2 (multiplexing)
- WebSocket for real-time (avoid polling)

---

## 11. Documentation & Runbooks

### 11.1 Deployment Runbook

**Pre-Deployment Checklist:**
- [ ] Code reviewed and merged to `main`
- [ ] Tests passing (unit, integration, E2E)
- [ ] Security audit passed (npm audit)
- [ ] Staging environment tested
- [ ] Backup taken (database + code)
- [ ] Team notified (deploy window)

**Deployment Steps:**
1. Trigger GitHub Actions workflow (manual or auto)
2. Monitor deployment logs
3. Wait for health check success
4. Smoke test critical endpoints (auth, orders, payments)
5. Monitor error logs for 10 minutes
6. Notify team (Slack: "Deployment successful")

**Rollback Criteria:**
- Health check fails
- Error rate >5%
- Critical bug reported
- Payment gateway failure

### 11.2 Incident Response Runbook

**Severity Levels:**
- **P0 (Critical):** Complete outage, payment failures
- **P1 (High):** Partial outage, degraded performance
- **P2 (Medium):** Non-critical bugs, minor performance issues
- **P3 (Low):** Cosmetic issues, feature requests

**Response Steps:**
1. **Detect:** Monitoring alert or user report
2. **Assess:** Determine severity, impact
3. **Notify:** Alert team (PagerDuty for P0/P1)
4. **Mitigate:** Apply temporary fix (e.g., rollback, disable feature)
5. **Resolve:** Deploy permanent fix
6. **Communicate:** Update customers (email, in-app)
7. **Post-Mortem:** Document incident, lessons learned

---

**Next Documents:**
- [Scalability Strategy](./SCALABILITY.md) — Deep dive into scaling
- [User Experience Flow](./UX_FLOW.md) — User journeys

---

*Document Classification: Confidential — Infrastructure Documentation*  
*Last Updated: June 2026*

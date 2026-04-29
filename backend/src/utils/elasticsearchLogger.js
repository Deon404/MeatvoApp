const { Client } = require('@elastic/elasticsearch');
const { logger } = require('./logger');

class ElasticsearchLogger {
  constructor() {
    this.client = null;
    this.indexPrefix = 'meatvo-logs';
    this.isInitialized = false;
  }

  async initialize() {
    try {
      const elasticsearchUrl = process.env.ELASTICSEARCH_URL || 'http://localhost:9200';
      
      this.client = new Client({
        node: elasticsearchUrl,
        auth: process.env.ELASTICSEARCH_USERNAME && process.env.ELASTICSEARCH_PASSWORD ? {
          username: process.env.ELASTICSEARCH_USERNAME,
          password: process.env.ELASTICSEARCH_PASSWORD
        } : undefined,
        tls: {
          rejectUnauthorized: process.env.ELASTICSEARCH_VERIFY_SSL !== 'false'
        }
      });

      // Test connection
      await this.client.ping();
      this.isInitialized = true;
      
      logger.info('elasticsearch_logger_initialized', { url: elasticsearchUrl });
    } catch (error) {
      logger.error('elasticsearch_logger_init_failed', { error: error.message });
      // Don't throw - allow application to continue without ES logging
    }
  }

  async logDocument(level, message, metadata = {}) {
    if (!this.isInitialized) {
      return;
    }

    try {
      const document = {
        timestamp: new Date().toISOString(),
        level: level.toLowerCase(),
        message,
        service: 'meatvo-api',
        environment: process.env.NODE_ENV || 'development',
        ...metadata
      };

      const indexName = `${this.indexPrefix}-${new Date().toISOString().split('T')[0]}`;

      await this.client.index({
        index: indexName,
        body: document
      });

      // Debug logging (remove in production)
      if (process.env.NODE_ENV !== 'production') {
        logger.debug('elasticsearch_log_sent', { 
          index: indexName, 
          level, 
          message: message.substring(0, 100) 
        });
      }
    } catch (error) {
      logger.error('elasticsearch_log_failed', { 
        error: error.message, 
        level, 
        message: message.substring(0, 100) 
      });
    }
  }

  async searchLogs(query, options = {}) {
    if (!this.isInitialized) {
      throw new Error('Elasticsearch logger not initialized');
    }

    const {
      from = 0,
      size = 100,
      sortBy = 'timestamp',
      sortOrder = 'desc',
      filters = {}
    } = options;

    try {
      const searchQuery = {
        index: `${this.indexPrefix}-*`,
        body: {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query,
                    fields: ['message', 'level', 'service', 'error']
                  }
                }
              ],
              filter: []
            }
          },
          sort: [
            { [sortBy]: { order: sortOrder } }
          ],
          from,
          size
        }
      };

      // Add filters
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          searchQuery.body.query.bool.filter.push({
            term: { [key]: value }
          });
        }
      });

      const response = await this.client.search(searchQuery);
      
      return {
        logs: response.body.hits.hits.map(hit => ({
          id: hit._id,
          ...hit._source
        })),
        total: response.body.hits.total.value,
        took: response.body.took
      };
    } catch (error) {
      logger.error('elasticsearch_search_failed', { error: error.message });
      throw error;
    }
  }

  async getLogStats(timeRange = '24h') {
    if (!this.isInitialized) {
      throw new Error('Elasticsearch logger not initialized');
    }

    try {
      const response = await this.client.search({
        index: `${this.indexPrefix}-*`,
        body: {
          size: 0,
          query: {
            range: {
              timestamp: {
                gte: `now-${timeRange}`
              }
            }
          },
          aggs: {
            levels: {
              terms: {
                field: 'level'
              }
            },
            services: {
              terms: {
                field: 'service'
              }
            },
            timeline: {
              date_histogram: {
                field: 'timestamp',
                interval: '1h'
              }
            }
          }
        }
      });

      return {
        total: response.body.hits.total.value,
        levels: response.body.aggregations.levels.buckets,
        services: response.body.aggregations.services.buckets,
        timeline: response.body.aggregations.timeline.buckets
      };
    } catch (error) {
      logger.error('elasticsearch_stats_failed', { error: error.message });
      throw error;
    }
  }

  async createIndexTemplate() {
    if (!this.isInitialized) {
      throw new Error('Elasticsearch logger not initialized');
    }

    try {
      const template = {
        index_patterns: [`${this.indexPrefix}-*`],
        template: {
          settings: {
            number_of_shards: 1,
            number_of_replicas: 0,
            'index.refresh_interval': '5s',
            'index.max_result_window': 50000
          },
          mappings: {
            properties: {
              timestamp: { type: 'date' },
              level: { type: 'keyword' },
              message: { type: 'text', analyzer: 'standard' },
              service: { type: 'keyword' },
              environment: { type: 'keyword' },
              request_id: { type: 'keyword' },
              user_id: { type: 'keyword' },
              client_ip: { type: 'ip' },
              http_method: { type: 'keyword' },
              request_url: { type: 'text' },
              status_code: { type: 'integer' },
              response_time: { type: 'float' },
              error: { type: 'text' },
              geoip: {
                properties: {
                  location: { type: 'geo_point' },
                  country_name: { type: 'keyword' },
                  city_name: { type: 'keyword' }
                }
              }
            }
          }
        }
      };

      await this.client.indices.putIndexTemplate({
        name: 'meatvo-logs-template',
        body: template
      });

      logger.info('elasticsearch_template_created');
    } catch (error) {
      logger.error('elasticsearch_template_failed', { error: error.message });
      throw error;
    }
  }

  async cleanupOldLogs(retentionDays = 30) {
    if (!this.isInitialized) {
      throw new Error('Elasticsearch logger not initialized');
    }

    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
      const cutoffTimestamp = cutoffDate.toISOString();

      const response = await this.client.deleteByQuery({
        index: `${this.indexPrefix}-*`,
        body: {
          query: {
            range: {
              timestamp: {
                lt: cutoffTimestamp
              }
            }
          }
        }
      });

      logger.info('elasticsearch_cleanup_completed', { 
        deleted: response.body.deleted,
        cutoffDate: cutoffTimestamp 
      });

      return response.body.deleted;
    } catch (error) {
      logger.error('elasticsearch_cleanup_failed', { error: error.message });
      throw error;
    }
  }
}

module.exports = new ElasticsearchLogger();

# =============================================================================
# Multi-stage Dockerfile for Nginx Web Service
# Optimized for production deployment on AWS ECS
# =============================================================================

# Build stage (if you had build steps for frontend assets)
FROM nginx:alpine AS production

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/

# Copy static web files
COPY *.html /usr/share/nginx/html/

# Create nginx user and set permissions for all required directories
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    chown -R nginx:nginx /run && \
    chmod -R 755 /run

# Switch to non-root user
USER nginx

# Expose port
EXPOSE 80

# Health check for ECS
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O - http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

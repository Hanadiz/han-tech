# ============================================
# HAN-TECH LTD - FRONTEND DOCKERFILE
# Deploy this NOW for the frontend on Render
# ============================================
FROM nginx:1.25-alpine

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy frontend files
COPY frontend/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create required directories
RUN mkdir -p /usr/share/nginx/html/assets/images/logo \
    && mkdir -p /usr/share/nginx/html/assets/images/hero \
    && mkdir -p /usr/share/nginx/html/assets/images/team \
    && mkdir -p /usr/share/nginx/html/assets/css \
    && mkdir -p /usr/share/nginx/html/assets/js

# Set proper permissions
RUN chown -R nginx:nginx /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

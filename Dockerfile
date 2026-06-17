FROM nginx:alpine

# --------------------------------------------------
# STEP 1: Create a built‑in test page (always works)
# --------------------------------------------------
RUN echo '<!DOCTYPE html><html><head><title>Han-Tech Test</title><style>body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;background:#0f0f1a;color:#fff;text-align:center}h1{font-size:3rem;color:#00b4d8}</style></head><body><div><h1>✅ Container is running!</h1><p>If you see this, the web server works.<br>Check <a href="/index.html">/index.html</a> for your site.</p></div></body></html>' > /usr/share/nginx/html/test.html

# --------------------------------------------------
# STEP 2: Copy your real frontend files
# --------------------------------------------------
COPY frontend/ /usr/share/nginx/html/

# --------------------------------------------------
# STEP 3: Show what ended up in the html folder
# --------------------------------------------------
RUN echo "========== FILES IN /usr/share/nginx/html/ ==========" && \
    ls -la /usr/share/nginx/html/ && \
    echo "======================================================"

# --------------------------------------------------
# STEP 4: Copy nginx config
# --------------------------------------------------
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
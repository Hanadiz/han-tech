// ============================================
// HAN-TECH CLIENT PORTAL AUTH GUARD
// Location: frontend/js/client-portal/auth-guard.js
// ============================================

(function() {
    const SESSION_DURATION = 2 * 60 * 60; // 2 hours in seconds
    const WARNING_THRESHOLD = 5 * 60; // Warn at 5 minutes
    let sessionTimeLeft = SESSION_DURATION;
    let timerInterval = null;

    window.AuthGuard = {
        check() {
            const token = sessionStorage.getItem('authToken') || localStorage.getItem('authToken');
            if (!token) {
                const currentPath = window.location.pathname;
                window.location.href = '/auth/login/index.html?redirect=' + encodeURIComponent(currentPath);
                return false;
            }
            return true;
        },

        getUser() {
            const email = sessionStorage.getItem('userEmail') || localStorage.getItem('userEmail') || 'user@example.com';
            const name = email.split('@')[0];
            const firstName = name.charAt(0).toUpperCase() + name.slice(1);
            const hour = new Date().getHours();
            const greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
            return {
                email: email,
                firstName: firstName,
                displayName: firstName,
                initials: name.substring(0, 2).toUpperCase(),
                greeting: greeting
            };
        },

        startSessionTimer(countdownEl, warningEl, warningMinsEl) {
            function update() {
                const mins = Math.floor(sessionTimeLeft / 60);
                const secs = sessionTimeLeft % 60;
                if (countdownEl) {
                    countdownEl.textContent = String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
                }
                if (sessionTimeLeft <= WARNING_THRESHOLD && sessionTimeLeft > 0 && warningEl) {
                    warningEl.style.display = 'block';
                    if (warningMinsEl) warningMinsEl.textContent = Math.ceil(sessionTimeLeft / 60);
                }
                if (sessionTimeLeft <= 0) {
                    clearInterval(timerInterval);
                    sessionStorage.clear();
                    localStorage.removeItem('authToken');
                    localStorage.removeItem('refreshToken');
                    alert('Your session has expired. Please log in again.');
                    window.location.href = '/auth/login/index.html';
                }
                sessionTimeLeft--;
            }
            update();
            timerInterval = setInterval(update, 1000);
        },

        refreshSession() {
            sessionTimeLeft = SESSION_DURATION;
            const warningEl = document.querySelector('.session-expiry-warning');
            if (warningEl) warningEl.style.display = 'none';
            sessionStorage.setItem('sessionRefreshed', Date.now().toString());
        },

        logout() {
            sessionStorage.clear();
            localStorage.removeItem('authToken');
            localStorage.removeItem('refreshToken');
            document.cookie.split(';').forEach(c => {
                document.cookie = c.split('=')[0].trim() + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
            });
            window.location.href = '/auth/logout/index.html';
        }
    };

    // Listen for storage events (multi-tab sync)
    window.addEventListener('storage', function(e) {
        if (e.key === 'authToken' && !e.newValue) {
            alert('You have been logged out from another tab.');
            window.location.href = '/auth/login/index.html';
        }
    });

    // Prevent back button after logout
    if (window.history && window.history.pushState) {
        window.history.pushState('forward', null, window.location.href);
        window.addEventListener('popstate', function() {
            window.history.pushState('forward', null, window.location.href);
        });
    }
})();
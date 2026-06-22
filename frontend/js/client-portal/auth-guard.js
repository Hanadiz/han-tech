// ============================================
// HAN-TECH AUTH GUARD (with RBAC)
// Location: frontend/js/client-portal/auth-guard.js
// ============================================

(function() {
    const SESSION_DURATION = 2 * 60 * 60; // 2 hours in seconds
    const WARNING_THRESHOLD = 5 * 60; // Warn at 5 minutes
    let sessionTimeLeft = SESSION_DURATION;
    let timerInterval = null;

    window.AuthGuard = {
        /**
         * Check if user is logged in and optionally verify a role.
         * @param {string} requiredRole - The role required to access the page.
         *   If omitted, any authenticated user is allowed.
         * @returns {boolean} true if access granted, false if redirected.
         */
        check(requiredRole) {
            const token = sessionStorage.getItem('authToken') || localStorage.getItem('authToken');
            if (!token) {
                const currentPath = window.location.pathname;
                window.location.href = '/auth/login/index.html?redirect=' + encodeURIComponent(currentPath);
                return false;
            }

            if (requiredRole) {
                const userRole = sessionStorage.getItem('userRole') || localStorage.getItem('userRole');
                if (userRole !== requiredRole) {
                    // Role mismatch – redirect to the user’s correct dashboard
                    this.redirectToOwnDashboard(userRole);
                    return false;
                }
            }

            return true;
        },

        /**
         * Redirect the user to the dashboard that matches their role.
         * @param {string} role - The user's actual role.
         */
        redirectToOwnDashboard(role) {
            const portals = {
                'super_admin': '/super-admin/dashboard/index.html',
                'admin': '/admin/dashboard/index.html',
                'client': '/client-portal/dashboard/index.html',
                'support_agent': '/support-agent/dashboard/index.html',
                'sales_rep': '/sales-rep/dashboard/index.html',
                'technical_engineer': '/technical-engineer/dashboard/index.html',
                'course_instructor': '/course-instructor/dashboard/index.html',
                'finance_officer': '/finance-officer/dashboard/index.html',
                'content_manager': '/content-manager/dashboard/index.html'
            };
            const target = portals[role] || '/index.html';
            window.location.href = target;
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
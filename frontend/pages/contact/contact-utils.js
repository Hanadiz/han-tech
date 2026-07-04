/**
 * contact-utils.js
 * Shared utility module for all contact pages
 * Han-Tech Ltd - Production v2.0
 * Dependencies: None (vanilla JS, no external libraries required)
 * 
 * Usage: <script src="/pages/contact/contact-utils.js"></script>
 */
(function(global) {
    'use strict';

    // ============ CONFIGURATION ============
    const CONFIG = {
        api: {
            contact: '/api/v1/contact/submit',
            newsletter: '/api/v1/newsletter/subscribe',
            sales: '/api/v1/sales/quote',
            support: '/api/v1/support/ticket',
            message: '/api/v1/contact/message',
            timeout: 15000 // 15 seconds
        },
        storage: {
            prefix: 'hantech_contact_',
            formData: 'form_data',
            userPreferences: 'user_prefs'
        },
        analytics: {
            enabled: true,
            events: {
                formStart: 'contact_form_start',
                formSubmit: 'contact_form_submit',
                formSuccess: 'contact_form_success',
                formError: 'contact_form_error',
                newsletterSignup: 'newsletter_signup',
                chatClick: 'chat_click',
                socialClick: 'social_click',
                directionClick: 'direction_click',
                pageView: 'contact_page_view',
                componentLoad: 'component_load'
            }
        },
        businessHours: {
            weekday: { start: { h: 8, m: 0 }, end: { h: 17, m: 0 } },
            saturday: { start: { h: 9, m: 0 }, end: { h: 13, m: 0 } },
            timezone: 'Africa/Kampala'
        }
    };

    // ============ STORAGE UTILITIES ============
    const Storage = {
        set(key, value, ttlMinutes = 30) {
            try {
                const item = {
                    value: value,
                    expiry: Date.now() + (ttlMinutes * 60 * 1000)
                };
                sessionStorage.setItem(CONFIG.storage.prefix + key, JSON.stringify(item));
                return true;
            } catch (e) {
                console.warn('Storage not available:', e);
                return false;
            }
        },
        get(key) {
            try {
                const raw = sessionStorage.getItem(CONFIG.storage.prefix + key);
                if (!raw) return null;
                const item = JSON.parse(raw);
                if (Date.now() > item.expiry) {
                    sessionStorage.removeItem(CONFIG.storage.prefix + key);
                    return null;
                }
                return item.value;
            } catch (e) {
                return null;
            }
        },
        remove(key) {
            try {
                sessionStorage.removeItem(CONFIG.storage.prefix + key);
            } catch (e) {}
        },
        clear() {
            try {
                const keys = Object.keys(sessionStorage);
                keys.forEach(key => {
                    if (key.startsWith(CONFIG.storage.prefix)) {
                        sessionStorage.removeItem(key);
                    }
                });
            } catch (e) {}
        }
    };

    // ============ VALIDATION UTILITIES ============
    const Validators = {
        email(value) {
            if (!value) return 'Email is required';
            const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
            if (!emailRegex.test(value)) return 'Please enter a valid email address';
            if (value.length > 254) return 'Email is too long';
            return null;
        },
        phone(value, required = false) {
            if (!value && !required) return null;
            if (!value && required) return 'Phone number is required';
            const cleaned = value.replace(/[\s\-()]/g, '');
            const phoneRegex = /^\+?\d{10,15}$/;
            if (!phoneRegex.test(cleaned)) return 'Please enter a valid phone number';
            return null;
        },
        name(value, fieldName = 'Name') {
            if (!value) return `${fieldName} is required`;
            if (value.trim().length < 2) return `${fieldName} must be at least 2 characters`;
            if (value.trim().length > 100) return `${fieldName} must be less than 100 characters`;
            if (!/^[a-zA-Z\s'-]+$/.test(value.trim())) return `${fieldName} contains invalid characters`;
            return null;
        },
        message(value, minLength = 10, maxLength = 2000) {
            if (!value) return 'Message is required';
            if (value.trim().length < minLength) return `Message must be at least ${minLength} characters`;
            if (value.length > maxLength) return `Message must be less than ${maxLength} characters`;
            return null;
        },
        required(value, fieldName = 'Field') {
            if (!value || !value.trim()) return `${fieldName} is required`;
            return null;
        },
        url(value) {
            if (!value) return null;
            try {
                new URL(value);
                return null;
            } catch (e) {
                return 'Please enter a valid URL';
            }
        }
    };

    // ============ FORM DATA PRESERVATION ============
    const FormPreserver = {
        save(formId, data) {
            const allData = Storage.get(CONFIG.storage.formData) || {};
            allData[formId] = {
                data: data,
                timestamp: Date.now()
            };
            Storage.set(CONFIG.storage.formData, allData, 60);
        },
        load(formId) {
            const allData = Storage.get(CONFIG.storage.formData);
            return allData && allData[formId] ? allData[formId].data : null;
        },
        restore(form, formId) {
            const saved = this.load(formId);
            if (!saved) return false;
            Object.keys(saved).forEach(key => {
                const field = form.querySelector(`[name="${key}"]`);
                if (field && field.type !== 'checkbox' && field.type !== 'radio') {
                    field.value = saved[key];
                }
            });
            return true;
        },
        clear(formId) {
            const allData = Storage.get(CONFIG.storage.formData) || {};
            delete allData[formId];
            Storage.set(CONFIG.storage.formData, allData);
        }
    };

    // ============ API SERVICE ============
    const API = {
        async submit(endpoint, data, options = {}) {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), CONFIG.api.timeout);

            try {
                const response = await fetch(endpoint, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest',
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
                    },
                    body: JSON.stringify({
                        ...data,
                        timestamp: new Date().toISOString(),
                        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
                        userAgent: navigator.userAgent,
                        pageUrl: window.location.href,
                        referrer: document.referrer || ''
                    }),
                    signal: controller.signal,
                    ...options
                });

                clearTimeout(timeoutId);

                if (!response.ok) {
                    const errorData = await response.json().catch(() => ({}));
                    throw new Error(errorData.message || `Request failed with status ${response.status}`);
                }

                return await response.json();
            } catch (error) {
                clearTimeout(timeoutId);
                if (error.name === 'AbortError') {
                    throw new Error('Request timed out. Please check your connection and try again.');
                }
                throw error;
            }
        },
        
        // Simulation mode for development/testing
        async simulate(endpoint, data, delay = 1500) {
            console.log(`[API Simulate] ${endpoint}:`, data);
            await new Promise(resolve => setTimeout(resolve, delay));
            
            // Simulate random success/failure (90% success rate)
            if (Math.random() > 0.9) {
                throw new Error('Simulated server error');
            }
            
            return { success: true, message: 'Simulated success' };
        }
    };

    // ============ TOAST NOTIFICATION SYSTEM ============
    class ToastManager {
        constructor() {
            this.container = null;
            this.toasts = [];
            this.init();
        }

        init() {
            this.container = document.getElementById('hantech-toast-container');
            if (!this.container) {
                this.container = document.createElement('div');
                this.container.id = 'hantech-toast-container';
                this.container.setAttribute('aria-live', 'polite');
                this.container.setAttribute('aria-atomic', 'true');
                this.container.style.cssText = `
                    position: fixed;
                    bottom: 24px;
                    right: 24px;
                    z-index: 100000;
                    display: flex;
                    flex-direction: column;
                    gap: 12px;
                    pointer-events: none;
                    max-width: 420px;
                `;
                document.body.appendChild(this.container);
            }
        }

        show(message, type = 'success', duration = 5000) {
            const icons = {
                success: '✓',
                error: '✕',
                warning: '⚠',
                info: 'ℹ'
            };

            const colors = {
                success: { bg: '#10b981', border: '#059669' },
                error: { bg: '#ef4444', border: '#dc2626' },
                warning: { bg: '#f59e0b', border: '#d97706' },
                info: { bg: '#3b82f6', border: '#2563eb' }
            };

            const color = colors[type] || colors.info;
            const toast = document.createElement('div');
            toast.className = 'hantech-toast';
            toast.setAttribute('role', 'alert');
            toast.style.cssText = `
                background: #ffffff;
                color: #1e293b;
                padding: 16px 20px;
                border-radius: 12px;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
                display: flex;
                align-items: flex-start;
                gap: 12px;
                pointer-events: all;
                animation: hantechSlideIn 0.35s cubic-bezier(0.68, -0.55, 0.265, 1.55);
                border-left: 4px solid ${color.border};
                font-size: 0.9rem;
                font-weight: 500;
                line-height: 1.4;
                position: relative;
                transition: all 0.3s ease;
            `;

            toast.innerHTML = `
                <span style="
                    width: 24px; height: 24px; 
                    border-radius: 50%; 
                    background: ${color.bg}; 
                    color: #fff; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center; 
                    font-size: 0.75rem;
                    font-weight: 700;
                    flex-shrink: 0;
                ">${icons[type]}</span>
                <span style="flex: 1;">${message}</span>
                <button aria-label="Close notification" style="
                    background: none; 
                    border: none; 
                    cursor: pointer; 
                    color: #94a3b8; 
                    padding: 4px;
                    font-size: 1.1rem;
                    line-height: 1;
                    transition: color 0.2s;
                    flex-shrink: 0;
                " onmouseover="this.style.color='#1e293b'" onmouseout="this.style.color='#94a3b8'">×</button>
            `;

            // Add animation keyframes if not exists
            if (!document.getElementById('hantech-toast-styles')) {
                const style = document.createElement('style');
                style.id = 'hantech-toast-styles';
                style.textContent = `
                    @keyframes hantechSlideIn {
                        from { transform: translateX(120%); opacity: 0; }
                        to { transform: translateX(0); opacity: 1; }
                    }
                    @keyframes hantechSlideOut {
                        from { transform: translateX(0); opacity: 1; }
                        to { transform: translateX(120%); opacity: 0; }
                    }
                    @media (prefers-color-scheme: dark) {
                        .hantech-toast {
                            background: #1e293b !important;
                            color: #e2e8f0 !important;
                        }
                    }
                `;
                document.head.appendChild(style);
            }

            this.container.appendChild(toast);
            this.toasts.push(toast);

            // Close button handler
            const closeBtn = toast.querySelector('button');
            closeBtn.addEventListener('click', () => this.remove(toast));

            // Auto remove
            if (duration > 0) {
                const timer = setTimeout(() => this.remove(toast), duration);
                
                // Pause on hover
                toast.addEventListener('mouseenter', () => clearTimeout(timer));
                toast.addEventListener('mouseleave', () => {
                    const newTimer = setTimeout(() => this.remove(toast), 2000);
                    toast._timer = newTimer;
                });
            }

            return toast;
        }

        remove(toast) {
            if (!toast || !toast.parentNode) return;
            toast.style.animation = 'hantechSlideOut 0.25s ease forwards';
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
                this.toasts = this.toasts.filter(t => t !== toast);
            }, 250);
        }

        success(message, duration) { return this.show(message, 'success', duration); }
        error(message, duration) { return this.show(message, 'error', duration); }
        warning(message, duration) { return this.show(message, 'warning', duration); }
        info(message, duration) { return this.show(message, 'info', duration); }

        clear() {
            this.toasts.forEach(toast => this.remove(toast));
        }
    }

    // Create global toast instance
    const toast = new ToastManager();

    // ============ ANALYTICS TRACKER ============
    const Analytics = {
        track(eventName, data = {}) {
            if (!CONFIG.analytics.enabled) return;

            const eventData = {
                event: eventName,
                page: window.location.pathname,
                timestamp: Date.now(),
                ...data
            };

            // Console log in development
            if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
                console.log(`[Analytics] ${eventName}:`, eventData);
            }

            // Send to analytics service (Google Analytics, custom endpoint, etc.)
            if (typeof gtag === 'function') {
                gtag('event', eventName, eventData);
            }

            // Custom analytics endpoint
            if (CONFIG.analytics.enabled) {
                navigator.sendBeacon?.('/api/v1/analytics/event', JSON.stringify(eventData));
            }
        },

        pageView() {
            this.track(CONFIG.analytics.events.pageView, {
                title: document.title,
                referrer: document.referrer
            });
        },

        formInteraction(formName, action) {
            this.track(`form_${action}`, { form: formName });
        },

        clickEvent(element, label) {
            this.track('click', {
                element: element,
                label: label,
                text: element?.textContent?.trim()?.substring(0, 50)
            });
        }
    };

    // ============ BUSINESS HOURS CHECKER ============
    const BusinessHours = {
        isOpen() {
            const now = new Date();
            const day = now.getDay(); // 0=Sun, 1=Mon, ..., 6=Sat
            const hours = now.getHours();
            const minutes = now.getMinutes();
            const currentMinutes = hours * 60 + minutes;

            if (day === 0) return false; // Sunday closed

            const config = day === 6 ? CONFIG.businessHours.saturday : CONFIG.businessHours.weekday;
            const startMinutes = config.start.h * 60 + config.start.m;
            const endMinutes = config.end.h * 60 + config.end.m;

            return currentMinutes >= startMinutes && currentMinutes < endMinutes;
        },

        getStatus() {
            return {
                isOpen: this.isOpen(),
                message: this.isOpen() ? 'We are open now' : 'We are closed now',
                nextOpen: this.getNextOpenTime()
            };
        },

        getNextOpenTime() {
            const now = new Date();
            const day = now.getDay();
            let nextOpen = new Date(now);

            if (this.isOpen()) return null;

            if (day === 0 || (day === 6 && now.getHours() >= 13)) {
                // Next Monday
                const daysUntilMonday = day === 0 ? 1 : 2;
                nextOpen.setDate(nextOpen.getDate() + daysUntilMonday);
                nextOpen.setHours(8, 0, 0, 0);
            } else if (day === 6) {
                nextOpen.setHours(9, 0, 0, 0);
            } else {
                nextOpen.setHours(8, 0, 0, 0);
                if (now.getHours() >= 17) {
                    nextOpen.setDate(nextOpen.getDate() + (day === 5 ? 2 : 1));
                }
            }

            return nextOpen;
        },

        getFormattedHours() {
            return [
                { day: 'Monday', hours: '8:00 AM - 5:00 PM' },
                { day: 'Tuesday', hours: '8:00 AM - 5:00 PM' },
                { day: 'Wednesday', hours: '8:00 AM - 5:00 PM' },
                { day: 'Thursday', hours: '8:00 AM - 5:00 PM' },
                { day: 'Friday', hours: '8:00 AM - 5:00 PM' },
                { day: 'Saturday', hours: '9:00 AM - 1:00 PM' },
                { day: 'Sunday', hours: 'Closed' }
            ];
        }
    };

    // ============ FORM VALIDATION HELPER ============
    class FormValidator {
        constructor(formElement, rules = {}) {
            this.form = formElement;
            this.rules = rules;
            this.errors = {};
            this.bindEvents();
        }

        bindEvents() {
            // Real-time validation on input
            this.form.querySelectorAll('input, textarea, select').forEach(field => {
                field.addEventListener('blur', () => this.validateField(field));
                field.addEventListener('input', () => {
                    if (field.classList.contains('hantech-error')) {
                        this.validateField(field);
                    }
                });
            });
        }

        validateField(field) {
            const fieldName = field.name || field.id;
            const rules = this.rules[fieldName];
            if (!rules) return true;

            const value = field.value;
            let error = null;

            for (const rule of rules) {
                if (typeof rule === 'function') {
                    error = rule(value);
                } else if (typeof rule === 'object' && rule.validate) {
                    error = rule.validate(value);
                }
                if (error) break;
            }

            this.setFieldState(field, error);
            return !error;
        }

        setFieldState(field, error) {
            const errorEl = field.parentElement.querySelector('.hantech-field-error') ||
                           document.getElementById(`${field.id}-error`);
            
            if (error) {
                field.classList.add('hantech-error');
                field.classList.remove('hantech-success');
                field.setAttribute('aria-invalid', 'true');
                if (errorEl) {
                    errorEl.textContent = error;
                    errorEl.style.display = 'flex';
                }
            } else if (field.value.trim()) {
                field.classList.remove('hantech-error');
                field.classList.add('hantech-success');
                field.setAttribute('aria-invalid', 'false');
                if (errorEl) {
                    errorEl.style.display = 'none';
                }
            } else {
                field.classList.remove('hantech-error', 'hantech-success');
                field.setAttribute('aria-invalid', 'false');
                if (errorEl) {
                    errorEl.style.display = 'none';
                }
            }
        }

        validateAll() {
            let isValid = true;
            const fields = this.form.querySelectorAll('input, textarea, select');
            
            fields.forEach(field => {
                if (this.rules[field.name] || this.rules[field.id]) {
                    if (!this.validateField(field)) {
                        isValid = false;
                    }
                }
            });

            if (!isValid) {
                const firstError = this.form.querySelector('.hantech-error');
                if (firstError) firstError.focus();
            }

            return isValid;
        }

        reset() {
            this.form.querySelectorAll('.hantech-error, .hantech-success').forEach(field => {
                field.classList.remove('hantech-error', 'hantech-success');
                field.setAttribute('aria-invalid', 'false');
            });
            this.form.querySelectorAll('.hantech-field-error').forEach(el => {
                el.style.display = 'none';
            });
        }
    }

    // ============ LOADING STATE MANAGER ============
    class LoadingManager {
        static show(button, text = 'Sending...') {
            button._originalHTML = button.innerHTML;
            button.disabled = true;
            button.classList.add('hantech-loading');
            button.innerHTML = `
                <span style="opacity: 0;">${button._originalHTML}</span>
                <span style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); display: flex; align-items: center; gap: 8px;">
                    <span class="hantech-spinner"></span> ${text}
                </span>
            `;
        }

        static hide(button) {
            if (button._originalHTML) {
                button.innerHTML = button._originalHTML;
                button._originalHTML = null;
            }
            button.disabled = false;
            button.classList.remove('hantech-loading');
        }
    }

    // ============ EXPORT PUBLIC API ============
    const HantechContact = {
        version: '2.0.0',
        config: CONFIG,
        storage: Storage,
        validators: Validators,
        api: API,
        toast: toast,
        analytics: Analytics,
        businessHours: BusinessHours,
        formValidator: FormValidator,
        loading: LoadingManager,
        formPreserver: FormPreserver,
        
        // Initialize common functionality
        init(options = {}) {
            // Merge custom config
            Object.assign(CONFIG, options);
            
            // Track page view
            Analytics.pageView();
            
            // Add global styles for form validation
            if (!document.getElementById('hantech-form-styles')) {
                const style = document.createElement('style');
                style.id = 'hantech-form-styles';
                style.textContent = `
                    .hantech-error { border-color: #ef4444 !important; box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1) !important; }
                    .hantech-success { border-color: #10b981 !important; box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1) !important; }
                    .hantech-field-error { 
                        color: #ef4444; 
                        font-size: 0.8rem; 
                        margin-top: 4px; 
                        display: none; 
                        align-items: center; 
                        gap: 6px; 
                    }
                    .hantech-loading { 
                        position: relative !important; 
                        opacity: 0.8; 
                        cursor: wait !important; 
                    }
                    .hantech-spinner {
                        width: 18px; height: 18px;
                        border: 2.5px solid rgba(255,255,255,0.3);
                        border-top-color: #fff;
                        border-radius: 50%;
                        animation: hantechSpin 0.6s linear infinite;
                        display: inline-block;
                    }
                    @keyframes hantechSpin { to { transform: rotate(360deg); } }
                `;
                document.head.appendChild(style);
            }

            console.log(`%c🚀 Han-Tech Contact Utils v${this.version} Ready`, 'color: #00b4d8; font-weight: bold;');
        }
    };

    // Expose to global scope
    global.HantechContact = HantechContact;

    // Auto-initialize if script is loaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => HantechContact.init());
    } else {
        HantechContact.init();
    }

})(typeof window !== 'undefined' ? window : this);
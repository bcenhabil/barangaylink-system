import axios from 'axios';

// Create axios instance with default config
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3001/api',
  timeout: 30000, // 30 seconds timeout
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for adding auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for handling errors
api.interceptors.response.use(
  (response) => {
    return response;
  },
  async (error) => {
    const originalRequest = error.config;

    // Handle token expiration (401)
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      try {
        // Try to refresh token
        const refreshToken = localStorage.getItem('refreshToken');
        if (refreshToken) {
          const response = await axios.post(
            `${import.meta.env.VITE_API_URL}/auth/refresh-token`,
            { refreshToken }
          );
          
          const { token, refreshToken: newRefreshToken } = response.data;
          
          // Update tokens in localStorage
          localStorage.setItem('token', token);
          localStorage.setItem('refreshToken', newRefreshToken);
          
          // Update authorization header
          api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
          originalRequest.headers['Authorization'] = `Bearer ${token}`;
          
          // Retry original request
          return api(originalRequest);
        }
      } catch (refreshError) {
        // Refresh token failed, redirect to login
        localStorage.removeItem('token');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('user');
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    // Handle other errors
    if (error.response) {
      // Server responded with error status
      const { status, data } = error.response;
      
      switch (status) {
        case 400:
          console.error('Bad Request:', data.message || 'Invalid request');
          break;
        case 403:
          console.error('Forbidden:', data.message || 'Access denied');
          break;
        case 404:
          console.error('Not Found:', data.message || 'Resource not found');
          break;
        case 429:
          console.error('Too Many Requests:', data.message || 'Rate limit exceeded');
          break;
        case 500:
          console.error('Server Error:', data.message || 'Internal server error');
          break;
        default:
          console.error(`Error ${status}:`, data.message || 'An error occurred');
      }
    } else if (error.request) {
      // Request made but no response
      console.error('Network Error:', 'No response from server. Please check your connection.');
    } else {
      // Something happened in setting up the request
      console.error('Request Error:', error.message);
    }

    return Promise.reject(error);
  }
);

// Helper function for file uploads
export const uploadFile = async (file, endpoint, onUploadProgress = null) => {
  const formData = new FormData();
  formData.append('file', file);

  return api.post(endpoint, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
    onUploadProgress,
  });
};

// Helper function for paginated requests
export const paginatedRequest = async (endpoint, params = {}) => {
  const response = await api.get(endpoint, { params });
  return {
    data: response.data.data,
    pagination: response.data.pagination,
  };
};

// Helper function for infinite scroll
export const infiniteScrollRequest = async (endpoint, page, limit = 20, params = {}) => {
  return paginatedRequest(endpoint, { page, limit, ...params });
};

// Export API methods for common operations
export const authAPI = {
  login: (credentials) => api.post('/auth/login', credentials),
  register: (userData) => api.post('/auth/register', userData),
  logout: () => api.post('/auth/logout'),
  forgotPassword: (email) => api.post('/auth/forgot-password', { email }),
  resetPassword: (data) => api.post('/auth/reset-password', data),
  verifyEmail: (token) => api.post('/auth/verify-email', { token }),
  getProfile: () => api.get('/auth/profile'),
  updateProfile: (data) => api.put('/auth/profile', data),
  changePassword: (data) => api.put('/auth/change-password', data),
};

export const requestsAPI = {
  getAll: (params) => api.get('/requests', { params }),
  getOne: (id) => api.get(`/requests/${id}`),
  create: (data) => api.post('/requests', data),
  update: (id, data) => api.put(`/requests/${id}`, data),
  delete: (id) => api.delete(`/requests/${id}`),
  getStats: () => api.get('/requests/stats'),
  createUpdate: (requestId, data) => api.post(`/requests/${requestId}/updates`, data),
};

export const eventsAPI = {
  getAll: (params) => api.get('/events', { params }),
  getOne: (id) => api.get(`/events/${id}`),
  create: (data) => api.post('/events', data),
  update: (id, data) => api.put(`/events/${id}`, data),
  delete: (id) => api.delete(`/events/${id}`),
  register: (eventId, data) => api.post(`/events/${eventId}/register`, data),
  unregister: (eventId) => api.delete(`/events/${eventId}/register`),
  getRegistrations: (eventId) => api.get(`/events/${eventId}/registrations`),
};

export const donationsAPI = {
  getAll: (params) => api.get('/donations', { params }),
  getOne: (id) => api.get(`/donations/${id}`),
  create: (data) => api.post('/donations', data),
  update: (id, data) => api.put(`/donations/${id}`, data),
  getStats: () => api.get('/donations/stats'),
  getDashboard: () => api.get('/donations/dashboard'),
};

export const volunteersAPI = {
  getAll: (params) => api.get('/volunteers', { params }),
  getOne: (id) => api.get(`/volunteers/${id}`),
  createProfile: (data) => api.post('/volunteers/profile', data),
  updateProfile: (data) => api.put('/volunteers/profile', data),
  getAssignments: () => api.get('/volunteers/assignments'),
  getHours: () => api.get('/volunteers/hours'),
  logHours: (data) => api.post('/volunteers/hours', data),
};

export const adminAPI = {
  getUsers: (params) => api.get('/admin/users', { params }),
  getUser: (id) => api.get(`/admin/users/${id}`),
  createUser: (data) => api.post('/admin/users', data),
  updateUser: (id, data) => api.put(`/admin/users/${id}`, data),
  deleteUser: (id) => api.delete(`/admin/users/${id}`),
  getAnalytics: () => api.get('/admin/analytics'),
  getSystemLogs: (params) => api.get('/admin/logs', { params }),
  getAuditLogs: (params) => api.get('/admin/audit-logs', { params }),
  exportData: (type) => api.get(`/admin/export/${type}`, { responseType: 'blob' }),
};

export const aiAPI = {
  chat: (message, context) => api.post('/ai/chat', { message, context }),
  prioritizePreview: (data) => api.post('/ai/priority-preview', data),
  predictResources: (data) => api.post('/ai/predict-resources', data),
  analyzeTrends: (timeframe) => api.post('/ai/analyze-trends', { timeframe }),
};

export const notificationsAPI = {
  getAll: (params) => api.get('/notifications', { params }),
  markAsRead: (id) => api.put(`/notifications/${id}/read`),
  markAllAsRead: () => api.put('/notifications/read-all'),
  delete: (id) => api.delete(`/notifications/${id}`),
  deleteAll: () => api.delete('/notifications'),
};

export const emergencyAPI = {
  getAlerts: (params) => api.get('/emergency/alerts', { params }),
  createAlert: (data) => api.post('/emergency/alerts', data),
  updateAlert: (id, data) => api.put(`/emergency/alerts/${id}`, data),
  getResources: () => api.get('/emergency/resources'),
  updateResource: (id, data) => api.put(`/emergency/resources/${id}`, data),
  getResponseTeams: () => api.get('/emergency/response-teams'),
};

export default api;

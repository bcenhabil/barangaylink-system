import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { toast } from 'react-hot-toast';

const AuthContext = createContext({});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState(localStorage.getItem('token'));
  const navigate = useNavigate();

  // Initialize auth state
  useEffect(() => {
    const initializeAuth = async () => {
      const storedToken = localStorage.getItem('token');
      const storedUser = localStorage.getItem('user');

      if (storedToken && storedUser) {
        try {
          // Set default authorization header
          api.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`;
          
          // Verify token with server
          await api.get('/auth/verify');
          
          setToken(storedToken);
          setUser(JSON.parse(storedUser));
        } catch (error) {
          // Token is invalid or expired
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          delete api.defaults.headers.common['Authorization'];
        }
      }
      
      setLoading(false);
    };

    initializeAuth();
  }, []);

  // Login function
  const login = async (email, password) => {
    try {
      setLoading(true);
      const response = await api.post('/auth/login', { email, password });
      
      const { token: newToken, user: userData } = response.data;
      
      // Store token and user data
      localStorage.setItem('token', newToken);
      localStorage.setItem('user', JSON.stringify(userData));
      
      // Set axios default header
      api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`;
      
      setToken(newToken);
      setUser(userData);
      
      toast.success('Login successful!');
      navigate('/dashboard');
      
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Login failed. Please try again.';
      toast.error(message);
      return { success: false, message };
    } finally {
      setLoading(false);
    }
  };

  // Register function
  const register = async (userData) => {
    try {
      setLoading(true);
      const response = await api.post('/auth/register', userData);
      
      toast.success('Registration successful! Please check your email for verification.');
      
      // Auto login after registration
      if (response.data.token) {
        localStorage.setItem('token', response.data.token);
        localStorage.setItem('user', JSON.stringify(response.data.user));
        api.defaults.headers.common['Authorization'] = `Bearer ${response.data.token}`;
        setToken(response.data.token);
        setUser(response.data.user);
        navigate('/dashboard');
      } else {
        navigate('/login');
      }
      
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Registration failed. Please try again.';
      toast.error(message);
      return { success: false, message };
    } finally {
      setLoading(false);
    }
  };

  // Logout function
  const logout = useCallback(async () => {
    try {
      await api.post('/auth/logout');
    } catch (error) {
      // Ignore logout errors
    } finally {
      // Clear local storage
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      
      // Clear axios headers
      delete api.defaults.headers.common['Authorization'];
      
      // Reset state
      setToken(null);
      setUser(null);
      
      // Navigate to login
      navigate('/login');
      
      toast.success('Logged out successfully');
    }
  }, [navigate]);

  // Update user profile
  const updateUser = (updatedUser) => {
    const newUser = { ...user, ...updatedUser };
    setUser(newUser);
    localStorage.setItem('user', JSON.stringify(newUser));
  };

  // Check if user has specific role
  const hasRole = (role) => {
    return user?.role === role;
  };

  // Check if user has any of the specified roles
  const hasAnyRole = (roles) => {
    return roles.includes(user?.role);
  };

  // Refresh token (if implementing refresh tokens)
  const refreshToken = async () => {
    try {
      const response = await api.post('/auth/refresh-token');
      const newToken = response.data.token;
      
      localStorage.setItem('token', newToken);
      api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`;
      setToken(newToken);
      
      return newToken;
    } catch (error) {
      logout();
      throw error;
    }
  };

  // Forgot password
  const forgotPassword = async (email) => {
    try {
      await api.post('/auth/forgot-password', { email });
      toast.success('Password reset instructions sent to your email');
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Failed to send reset instructions';
      toast.error(message);
      return { success: false, message };
    }
  };

  // Reset password
  const resetPassword = async (token, password) => {
    try {
      await api.post('/auth/reset-password', { token, password });
      toast.success('Password reset successful. You can now login with your new password.');
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Failed to reset password';
      toast.error(message);
      return { success: false, message };
    }
  };

  // Verify email
  const verifyEmail = async (token) => {
    try {
      await api.post('/auth/verify-email', { token });
      toast.success('Email verified successfully!');
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.message || 'Failed to verify email';
      toast.error(message);
      return { success: false, message };
    }
  };

  const value = {
    user,
    token,
    loading,
    login,
    register,
    logout,
    updateUser,
    hasRole,
    hasAnyRole,
    refreshToken,
    forgotPassword,
    resetPassword,
    verifyEmail
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export default AuthContext;

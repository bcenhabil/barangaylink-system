import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './contexts/AuthContext';
import { SocketProvider } from './contexts/SocketContext';
import { ThemeProvider } from './contexts/ThemeContext';
import Layout from './components/Layout/Layout';
import Login from './pages/Auth/Login';
import Register from './pages/Auth/Register';
import ForgotPassword from './pages/Auth/ForgotPassword';
import ResetPassword from './pages/Auth/ResetPassword';
import VerifyEmail from './pages/Auth/VerifyEmail';
import Dashboard from './pages/Dashboard/Dashboard';
import Requests from './pages/Requests/Requests';
import RequestDetail from './pages/Requests/RequestDetail';
import NewRequest from './pages/Requests/NewRequest';
import Events from './pages/Events/Events';
import EventDetail from './pages/Events/EventDetail';
import NewEvent from './pages/Events/NewEvent';
import Donations from './pages/Donations/Donations';
import NewDonation from './pages/Donations/NewDonation';
import Volunteers from './pages/Volunteers/Volunteers';
import VolunteerProfile from './pages/Volunteers/VolunteerProfile';
import Announcements from './pages/Announcements/Announcements';
import Messages from './pages/Messages/Messages';
import Profile from './pages/Profile/Profile';
import Settings from './pages/Settings/Settings';
import Admin from './pages/Admin/Admin';
import Analytics from './pages/Admin/Analytics';
import UserManagement from './pages/Admin/UserManagement';
import Emergency from './pages/Emergency/Emergency';
import Chatbot from './components/Chatbot/Chatbot';
import ProtectedRoute from './components/Auth/ProtectedRoute';
import NotFound from './pages/NotFound/NotFound';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

function App() {
  const [isChatbotOpen, setIsChatbotOpen] = useState(false);

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <AuthProvider>
          <SocketProvider>
            <Router>
              <div className="min-h-screen bg-gray-50 dark:bg-gray-900 transition-colors">
                <Toaster 
                  position="top-right"
                  toastOptions={{
                    duration: 4000,
                    style: {
                      background: '#363636',
                      color: '#fff',
                    },
                    success: {
                      duration: 3000,
                      iconTheme: {
                        primary: '#10b981',
                        secondary: '#fff',
                      },
                    },
                    error: {
                      duration: 4000,
                      iconTheme: {
                        primary: '#ef4444',
                        secondary: '#fff',
                      },
                    },
                  }}
                />
                
                <Routes>
                  {/* Public routes */}
                  <Route path="/login" element={<Login />} />
                  <Route path="/register" element={<Register />} />
                  <Route path="/forgot-password" element={<ForgotPassword />} />
                  <Route path="/reset-password" element={<ResetPassword />} />
                  <Route path="/verify-email" element={<VerifyEmail />} />
                  
                  {/* Protected routes with layout */}
                  <Route element={<ProtectedRoute />}>
                    <Route element={<Layout />}>
                      <Route path="/" element={<Navigate to="/dashboard" replace />} />
                      <Route path="/dashboard" element={<Dashboard />} />
                      
                      {/* Requests */}
                      <Route path="/requests" element={<Requests />} />
                      <Route path="/requests/new" element={<NewRequest />} />
                      <Route path="/requests/:id" element={<RequestDetail />} />
                      
                      {/* Events */}
                      <Route path="/events" element={<Events />} />
                      <Route path="/events/new" element={<NewEvent />} />
                      <Route path="/events/:id" element={<EventDetail />} />
                      
                      {/* Donations */}
                      <Route path="/donations" element={<Donations />} />
                      <Route path="/donations/new" element={<NewDonation />} />
                      
                      {/* Volunteers */}
                      <Route path="/volunteers" element={<Volunteers />} />
                      <Route path="/volunteers/:id" element={<VolunteerProfile />} />
                      
                      {/* Announcements */}
                      <Route path="/announcements" element={<Announcements />} />
                      
                      {/* Messages */}
                      <Route path="/messages" element={<Messages />} />
                      <Route path="/messages/:id" element={<Messages />} />
                      
                      {/* Profile & Settings */}
                      <Route path="/profile" element={<Profile />} />
                      <Route path="/settings" element={<Settings />} />
                      
                      {/* Emergency */}
                      <Route path="/emergency" element={<Emergency />} />
                      
                      {/* Admin routes */}
                      <Route path="/admin" element={
                        <ProtectedRoute roles={['ADMIN', 'MODERATOR']}>
                          <Admin />
                        </ProtectedRoute>
                      } />
                      <Route path="/admin/analytics" element={
                        <ProtectedRoute roles={['ADMIN', 'MODERATOR']}>
                          <Analytics />
                        </ProtectedRoute>
                      } />
                      <Route path="/admin/users" element={
                        <ProtectedRoute roles={['ADMIN']}>
                          <UserManagement />
                        </ProtectedRoute>
                      } />
                    </Route>
                  </Route>
                  
                  {/* 404 */}
                  <Route path="*" element={<NotFound />} />
                </Routes>
                
                {/* Floating Chatbot Button */}
                <button
                  onClick={() => setIsChatbotOpen(!isChatbotOpen)}
                  className="fixed bottom-6 right-6 bg-blue-600 text-white p-4 rounded-full shadow-lg hover:bg-blue-700 transition-all duration-300 z-50 flex items-center justify-center group"
                  aria-label="Open chatbot"
                >
                  {isChatbotOpen ? (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  ) : (
                    <>
                      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
                      </svg>
                      <span className="absolute -top-2 -right-2 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center animate-pulse">
                        24/7
                      </span>
                    </>
                  )}
                </button>
                
                {/* Chatbot Modal */}
                {isChatbotOpen && (
                  <Chatbot onClose={() => setIsChatbotOpen(false)} />
                )}
              </div>
            </Router>
          </SocketProvider>
        </AuthProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;

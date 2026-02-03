import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { 
  Users, 
  ClipboardList, 
  Calendar, 
  DollarSign, 
  AlertCircle,
  TrendingUp,
  Clock,
  CheckCircle,
  MapPin
} from 'lucide-react';
import { motion } from 'framer-motion';
import { useAuth } from '../../contexts/AuthContext';
import { useSocket } from '../../contexts/SocketContext';
import api from '../../services/api';
import StatCard from '../../components/Dashboard/StatCard';
import QuickActions from '../../components/Dashboard/QuickActions';
import RecentRequests from '../../components/Dashboard/RecentRequests';
import UpcomingEvents from '../../components/Dashboard/UpcomingEvents';
import PriorityAlerts from '../../components/Dashboard/PriorityAlerts';
import LoadingSpinner from '../../components/Common/LoadingSpinner';
import ErrorMessage from '../../components/Common/ErrorMessage';

const Dashboard = () => {
  const { user } = useAuth();
  const { socket } = useSocket();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState([]);
  const [realTimeStats, setRealTimeStats] = useState({
    activeVolunteers: 0,
    pendingRequests: 0,
    ongoingEvents: 0
  });

  // Fetch dashboard data
  const { data: dashboardData, isLoading, error } = useQuery({
    queryKey: ['dashboard'],
    queryFn: async () => {
      const response = await api.get('/dashboard');
      return response.data.data;
    },
    refetchInterval: 60000, // Refetch every minute
  });

  // Fetch recent requests
  const { data: recentRequests } = useQuery({
    queryKey: ['recent-requests'],
    queryFn: async () => {
      const response = await api.get('/requests?limit=5&sortBy=createdAt&sortOrder=desc');
      return response.data.data.requests;
    }
  });

  // Fetch upcoming events
  const { data: upcomingEvents } = useQuery({
    queryKey: ['upcoming-events'],
    queryFn: async () => {
      const response = await api.get('/events?limit=3&status=UPCOMING');
      return response.data.data.events;
    }
  });

  // Socket.io listeners for real-time updates
  useEffect(() => {
    if (!socket) return;

    socket.on('notification', (notification) => {
      setNotifications(prev => [notification, ...prev.slice(0, 9)]);
    });

    socket.on('stats-updated', (stats) => {
      setRealTimeStats(stats);
    });

    socket.on('new-request', (request) => {
      if (user.role === 'ADMIN' || user.role === 'MODERATOR') {
        setNotifications(prev => [{
          type: 'new-request',
          title: 'New Request',
          message: `New ${request.category} request: ${request.title}`,
          timestamp: new Date()
        }, ...prev.slice(0, 9)]);
      }
    });

    return () => {
      socket.off('notification');
      socket.off('stats-updated');
      socket.off('new-request');
    };
  }, [socket, user.role]);

  if (isLoading) {
    return <LoadingSpinner fullScreen />;
  }

  if (error) {
    return <ErrorMessage message="Failed to load dashboard data" />;
  }

  const stats = dashboardData?.stats || {};
  const userCounts = dashboardData?.userCounts || {};

  return (
    <div className="space-y-6">
      {/* Header */}
      <motion.div 
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4"
      >
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            Welcome back, {user?.firstName}!
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mt-2">
            Here's what's happening in your community today.
          </p>
        </div>
        <div className="flex items-center space-x-4">
          <span className="px-3 py-1 bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200 rounded-full text-sm font-medium">
            {user?.role}
          </span>
          <button
            onClick={() => navigate('/notifications')}
            className="relative p-2 text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-white"
          >
            <AlertCircle className="w-6 h-6" />
            {notifications.length > 0 && (
              <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center animate-pulse">
                {notifications.length}
              </span>
            )}
          </button>
        </div>
      </motion.div>

      {/* Stats Grid */}
      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5, delay: 0.2 }}
        className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6"
      >
        <StatCard
          title="Pending Requests"
          value={stats.pendingRequests || 0}
          change={stats.requestGrowth > 0 ? `+${stats.requestGrowth}%` : null}
          icon={<ClipboardList className="w-6 h-6" />}
          color="yellow"
          link="/requests?status=PENDING"
          loading={isLoading}
        />
        <StatCard
          title="Active Volunteers"
          value={stats.activeVolunteers || 0}
          change={stats.volunteerGrowth > 0 ? `+${stats.volunteerGrowth}%` : null}
          icon={<Users className="w-6 h-6" />}
          color="green"
          link="/volunteers"
          loading={isLoading}
        />
        <StatCard
          title="Upcoming Events"
          value={stats.upcomingEvents || 0}
          change={stats.eventGrowth > 0 ? `+${stats.eventGrowth}%` : null}
          icon={<Calendar className="w-6 h-6" />}
          color="blue"
          link="/events"
          loading={isLoading}
        />
        <StatCard
          title="Total Donations"
          value={`₱${(stats.totalDonations || 0).toLocaleString()}`}
          change={stats.donationGrowth > 0 ? `+${stats.donationGrowth}%` : null}
          icon={<DollarSign className="w-6 h-6" />}
          color="purple"
          link="/donations"
          loading={isLoading}
        />
      </motion.div>

      {/* Real-time Stats */}
      {user.role === 'ADMIN' && (
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl shadow-lg p-6 text-white"
        >
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Real-time Community Activity</h3>
            <TrendingUp className="w-5 h-5" />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold">{realTimeStats.activeVolunteers}</div>
              <div className="text-sm opacity-90">Volunteers Online</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">{realTimeStats.pendingRequests}</div>
              <div className="text-sm opacity-90">Requests Today</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold">{realTimeStats.ongoingEvents}</div>
              <div className="text-sm opacity-90">Events Now</div>
            </div>
          </div>
        </motion.div>
      )}

      {/* Priority Alerts */}
      <PriorityAlerts />

      {/* Main Content */}
      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5, delay: 0.4 }}
        className="grid grid-cols-1 lg:grid-cols-3 gap-6"
      >
        <div className="lg:col-span-2 space-y-6">
          {/* Quick Actions */}
          <QuickActions userRole={user?.role} />
          
          {/* Recent Requests */}
          <RecentRequests requests={recentRequests || []} />
          
          {/* Performance Metrics */}
          {user.role === 'ADMIN' && (
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                System Performance
              </h3>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <Clock className="w-5 h-5 text-gray-500" />
                    <span className="text-gray-700 dark:text-gray-300">Avg. Response Time</span>
                  </div>
                  <span className="font-semibold">2.4 hours</span>
                </div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <CheckCircle className="w-5 h-5 text-green-500" />
                    <span className="text-gray-700 dark:text-gray-300">Request Resolution Rate</span>
                  </div>
                  <span className="font-semibold">94%</span>
                </div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <MapPin className="w-5 h-5 text-blue-500" />
                    <span className="text-gray-700 dark:text-gray-300">Active Barangays</span>
                  </div>
                  <span className="font-semibold">12</span>
                </div>
              </div>
            </div>
          )}
        </div>
        
        <div className="space-y-6">
          {/* Upcoming Events */}
          <UpcomingEvents events={upcomingEvents || []} />
          
          {/* Community Updates */}
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Community Updates
            </h3>
            <div className="space-y-4">
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center">
                    <CheckCircle className="w-4 h-4 text-green-600 dark:text-green-400" />
                  </div>
                </div>
                <div>
                  <p className="text-sm text-gray-900 dark:text-white">
                    Food assistance distributed to 50 families in Zone 3
                  </p>
                  <p className="text-xs text-gray-500">2 hours ago</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                    <Calendar className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                  </div>
                </div>
                <div>
                  <p className="text-sm text-gray-900 dark:text-white">
                    Community clean-up scheduled for Saturday, 9AM at the plaza
                  </p>
                  <p className="text-xs text-gray-500">1 day ago</p>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0">
                  <div className="w-8 h-8 bg-purple-100 dark:bg-purple-900 rounded-full flex items-center justify-center">
                    <Users className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                  </div>
                </div>
                <div>
                  <p className="text-sm text-gray-900 dark:text-white">
                    15 new volunteers joined this week. Welcome to the team!
                  </p>
                  <p className="text-xs text-gray-500">3 days ago</p>
                </div>
              </div>
            </div>
            <Link 
              to="/announcements" 
              className="mt-4 inline-flex items-center text-sm text-blue-600 dark:text-blue-400 hover:underline"
            >
              View all announcements
              <svg className="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </Link>
          </div>
          
          {/* Quick Links */}
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Quick Links
            </h3>
            <div className="grid grid-cols-2 gap-3">
              <Link
                to="/requests/new"
                className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg text-blue-700 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors text-center"
              >
                <div className="font-medium">Request Help</div>
                <div className="text-xs opacity-75">Get assistance</div>
              </Link>
              <Link
                to="/events"
                className="p-3 bg-green-50 dark:bg-green-900/20 rounded-lg text-green-700 dark:text-green-400 hover:bg-green-100 dark:hover:bg-green-900/30 transition-colors text-center"
              >
                <div className="font-medium">Join Events</div>
                <div className="text-xs opacity-75">Volunteer now</div>
              </Link>
              <Link
                to="/donations/new"
                className="p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg text-purple-700 dark:text-purple-400 hover:bg-purple-100 dark:hover:bg-purple-900/30 transition-colors text-center"
              >
                <div className="font-medium">Make Donation</div>
                <div className="text-xs opacity-75">Support community</div>
              </Link>
              <Link
                to="/emergency"
                className="p-3 bg-red-50 dark:bg-red-900/20 rounded-lg text-red-700 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/30 transition-colors text-center"
              >
                <div className="font-medium">Emergency</div>
                <div className="text-xs opacity-75">Get help fast</div>
              </Link>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
};

export default Dashboard;

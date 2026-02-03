const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding...');

  // Create default admin user
  const adminPassword = await bcrypt.hash('admin123', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@barangaylink.ph' },
    update: {},
    create: {
      email: 'admin@barangaylink.ph',
      password: adminPassword,
      firstName: 'Admin',
      lastName: 'User',
      role: 'ADMIN',
      contactNumber: '09123456789',
      address: 'Barangay Hall, Manila',
      isVerified: true
    }
  });
  console.log(`✅ Created admin user: ${admin.email}`);

  // Create test moderator
  const moderatorPassword = await bcrypt.hash('mod123', 12);
  const moderator = await prisma.user.upsert({
    where: { email: 'moderator@barangaylink.ph' },
    update: {},
    create: {
      email: 'moderator@barangaylink.ph',
      password: moderatorPassword,
      firstName: 'Moderator',
      lastName: 'User',
      role: 'MODERATOR',
      contactNumber: '09123456788',
      address: 'Zone 1, Barangay Manila',
      isVerified: true
    }
  });
  console.log(`✅ Created moderator user: ${moderator.email}`);

  // Create test volunteer
  const volunteerPassword = await bcrypt.hash('volunteer123', 12);
  const volunteer = await prisma.user.upsert({
    where: { email: 'volunteer@barangaylink.ph' },
    update: {},
    create: {
      email: 'volunteer@barangaylink.ph',
      password: volunteerPassword,
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      role: 'VOLUNTEER',
      contactNumber: '09123456787',
      address: '123 Main St, Barangay Manila',
      isVerified: true
    }
  });

  // Create volunteer profile
  await prisma.volunteerProfile.upsert({
    where: { userId: volunteer.id },
    update: {},
    create: {
      userId: volunteer.id,
      skills: ['First Aid', 'Cooking', 'Community Organizing'],
      interests: ['Medical Missions', 'Clean-up Drives', 'Youth Programs'],
      availability: 'Weekends',
      isActive: true
    }
  });
  console.log(`✅ Created volunteer user: ${volunteer.email}`);

  // Create test community member
  const memberPassword = await bcrypt.hash('member123', 12);
  const member = await prisma.user.upsert({
    where: { email: 'member@barangaylink.ph' },
    update: {},
    create: {
      email: 'member@barangaylink.ph',
      password: memberPassword,
      firstName: 'Maria',
      lastName: 'Santos',
      role: 'MEMBER',
      contactNumber: '09123456786',
      address: '456 Oak St, Barangay Manila',
      isVerified: true
    }
  });
  console.log(`✅ Created member user: ${member.email}`);

  // Create sample requests
  const sampleRequests = [
    {
      title: 'Need Medical Assistance',
      description: 'Elderly neighbor needs prescription medication for hypertension. Cannot go to pharmacy due to mobility issues.',
      category: 'MEDICAL',
      priority: 'HIGH',
      status: 'PENDING',
      address: '123 Main St, Barangay Manila',
      userId: member.id
    },
    {
      title: 'Food Assistance Needed',
      description: 'Family of 5 lost income due to pandemic. Need rice and canned goods for this week.',
      category: 'FOOD',
      priority: 'HIGH',
      status: 'IN_PROGRESS',
      address: '456 Oak St, Barangay Manila',
      userId: member.id,
      assignedToId: volunteer.id
    },
    {
      title: 'Street Light Repair',
      description: 'Street light post #5 on Maple Street is not working. Area is dark at night, safety concern.',
      category: 'INFRASTRUCTURE',
      priority: 'MEDIUM',
      status: 'PENDING',
      address: 'Maple Street, Barangay Manila',
      userId: member.id
    },
    {
      title: 'Flood in Area',
      description: 'Heavy rain caused flooding in Zone 3. Water level is knee-high. Need sandbags and evacuation assistance.',
      category: 'EMERGENCY',
      priority: 'URGENT',
      status: 'IN_PROGRESS',
      address: 'Zone 3, Barangay Manila',
      userId: member.id,
      assignedToId: volunteer.id
    },
    {
      title: 'Scholarship Application Help',
      description: 'Need assistance with barangay scholarship application for college student.',
      category: 'EDUCATION',
      priority: 'MEDIUM',
      status: 'RESOLVED',
      address: '789 Pine St, Barangay Manila',
      userId: member.id
    }
  ];

  for (const requestData of sampleRequests) {
    const request = await prisma.request.create({
      data: requestData
    });
    
    // Create initial update
    await prisma.requestUpdate.create({
      data: {
        requestId: request.id,
        description: 'Request created',
        status: request.status,
        createdById: request.userId
      }
    });
  }
  console.log(`✅ Created ${sampleRequests.length} sample requests`);

  // Create sample events
  const sampleEvents = [
    {
      title: 'Community Clean-up Drive',
      description: 'Monthly community clean-up. Bring gloves and bags. Refreshments will be provided.',
      type: 'CLEANUP',
      date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
      location: 'Barangay Plaza',
      maxAttendees: 50,
      status: 'UPCOMING',
      createdById: admin.id
    },
    {
      title: 'Medical Mission',
      description: 'Free medical check-up, blood pressure monitoring, and basic medicines.',
      type: 'MEDICAL_MISSION',
      date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000), // 14 days from now
      location: 'Barangay Health Center',
      maxAttendees: 100,
      status: 'UPCOMING',
      createdById: admin.id
    },
    {
      title: 'Disaster Preparedness Training',
      description: 'Learn basic first aid, fire safety, and emergency response procedures.',
      type: 'TRAINING',
      date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000), // 3 days from now
      location: 'Barangay Hall',
      maxAttendees: 30,
      status: 'UPCOMING',
      createdById: moderator.id
    }
  ];

  for (const eventData of sampleEvents) {
    await prisma.event.create({
      data: eventData
    });
  }
  console.log(`✅ Created ${sampleEvents.length} sample events`);

  // Create sample announcements
  const sampleAnnouncements = [
    {
      title: 'Water Interruption Schedule',
      content: 'Water service will be interrupted on Friday, 8AM-5PM for pipeline maintenance. Please store water accordingly.',
      type: 'ANNOUNCEMENT',
      priority: 'MEDIUM',
      isPinned: true,
      createdById: admin.id
    },
    {
      title: 'Community Pantry Schedule',
      content: 'Community pantry will be open every Tuesday and Thursday, 8AM-12PM at the barangay hall. Bring valid ID.',
      type: 'ANNOUNCEMENT',
      priority: 'MEDIUM',
      createdById: moderator.id
    },
    {
      title: 'Emergency Alert: Typhoon Warning',
      content: 'Typhoon signal #2 raised. Prepare emergency kits. Evacuation centers are open at barangay hall and school.',
      type: 'EMERGENCY',
      priority: 'URGENT',
      isPinned: true,
      createdById: admin.id
    }
  ];

  for (const announcementData of sampleAnnouncements) {
    await prisma.announcement.create({
      data: announcementData
    });
  }
  console.log(`✅ Created ${sampleAnnouncements.length} sample announcements`);

  // Create sample donation campaign
  const campaign = await prisma.campaign.create({
    data: {
      title: 'Educational Assistance Fund',
      description: 'Help send underprivileged children to school. Donations will be used for school supplies, uniforms, and tuition fees.',
      targetAmount: 50000,
      currentAmount: 12500,
      endDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000), // 90 days from now
      status: 'ACTIVE',
      createdById: admin.id
    }
  });
  console.log(`✅ Created donation campaign: ${campaign.title}`);

  // Create sample donations
  const sampleDonations = [
    {
      type: 'CASH',
      amount: 5000,
      description: 'Educational fund donation',
      donorId: volunteer.id,
      campaignId: campaign.id,
      status: 'RECEIVED'
    },
    {
      type: 'FOOD',
      description: '10 sacks of rice for community pantry',
      donorId: member.id,
      status: 'RECEIVED'
    },
    {
      type: 'MEDICINE',
      description: 'Box of basic medicines for medical mission',
      donorId: moderator.id,
      status: 'RECEIVED'
    }
  ];

  for (const donationData of sampleDonations) {
    await prisma.donation.create({
      data: donationData
    });
  }
  console.log(`✅ Created ${sampleDonations.length} sample donations`);

  // Create sample emergency alert
  const emergencyAlert = await prisma.emergencyAlert.create({
    data: {
      title: 'Fire Incident Reported',
      description: 'Small fire reported near the market. Fire department responding. Avoid the area.',
      type: 'FIRE',
      severity: 'HIGH',
      location: 'Market Area, Barangay Manila',
      status: 'ACTIVE',
      createdById: admin.id
    }
  });
  console.log(`✅ Created emergency alert: ${emergencyAlert.title}`);

  // Create sample resources
  const sampleResources = [
    {
      name: 'Rice',
      category: 'FOOD',
      quantity: 100,
      unit: 'sacks',
      location: 'Barangay Storage',
      minLevel: 20,
      maxLevel: 200
    },
    {
      name: 'Bottled Water',
      category: 'WATER',
      quantity: 500,
      unit: 'bottles',
      location: 'Barangay Storage',
      minLevel: 100,
      maxLevel: 1000
    },
    {
      name: 'First Aid Kit',
      category: 'MEDICINE',
      quantity: 25,
      unit: 'kits',
      location: 'Health Center',
      minLevel: 10,
      maxLevel: 50
    },
    {
      name: 'Emergency Blanket',
      category: 'SHELTER',
      quantity: 150,
      unit: 'pieces',
      location: 'Evacuation Center',
      minLevel: 50,
      maxLevel: 300
    }
  ];

  for (const resourceData of sampleResources) {
    await prisma.resource.create({
      data: resourceData
    });
  }
  console.log(`✅ Created ${sampleResources.length} sample resources`);

  // Create sample activity logs
  const activityLogs = [
    {
      userId: admin.id,
      action: 'SYSTEM_INITIALIZED',
      entityType: 'SYSTEM',
      details: { message: 'Database seeded with initial data' }
    },
    {
      userId: admin.id,
      action: 'USER_CREATED',
      entityType: 'USER',
      entityId: admin.id,
      details: { email: admin.email, role: admin.role }
    }
  ];

  for (const logData of activityLogs) {
    await prisma.activityLog.create({
      data: logData
    });
  }
  console.log(`✅ Created ${activityLogs.length} sample activity logs`);

  console.log('🎉 Database seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

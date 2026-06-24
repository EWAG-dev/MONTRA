const path = require('path');
const { defineConfig } = require('vite');

module.exports = defineConfig({
  build: {
    rollupOptions: {
      input: {
        index: path.resolve(__dirname, 'index.html'),
        findACoach: path.resolve(__dirname, 'find-a-coach.html'),
        coachProfile: path.resolve(__dirname, 'coach-profile.html'),
        forTrainers: path.resolve(__dirname, 'for-trainers.html'),
        howItWorks: path.resolve(__dirname, 'how-it-works.html'),
        pricing: path.resolve(__dirname, 'pricing.html'),
        services: path.resolve(__dirname, 'services.html'),
        quiz: path.resolve(__dirname, 'quiz.html'),
        trainerApply: path.resolve(__dirname, 'trainer-apply.html'),
        trainerOnboarding: path.resolve(__dirname, 'trainer-onboarding.html'),
        trainerApplication: path.resolve(__dirname, 'trainer-application.html'),
        about: path.resolve(__dirname, 'about.html'),
        admin: path.resolve(__dirname, 'admin.html'),
        // coaches.html removed — orphaned page never linked anywhere; firebase.json
        // redirects /coaches.html → / (find-a-coach = index.html is canonical)
      },
    },
  },
});

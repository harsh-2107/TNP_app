/// Centralized, user-facing copy. Keeping strings here (rather than
/// inline in widgets) is the seam a future localization pass (intl /
/// ARB files) would hang off of.
class AppStrings {
  const AppStrings._();

  // App.
  static const appName = 'IIIT Nagpur';
  static const appTagline = 'Training & Placement Cell';

  // Auth.
  static const signInWithCollegeCredentials = 'Sign in with your college credentials';
  static const collegeEmailLabel = 'College Email ID';
  static const collegeEmailHint = 'your.roll@iiitn.ac.in';
  static const passwordLabel = 'Password';
  static const passwordHint = '••••••••';
  static const signIn = 'Sign In';
  static const continueWithGoogle = 'Continue with Google';
  static const authHelperText =
      'Use your official college email ID for verification. Your profile data will be automatically fetched.';

  // Home.
  static const activeOpportunities = 'Active Opportunities';
  static const eligible = 'Eligible';
  static const notEligible = 'Not Eligible';

  // Profile.
  static const editProfile = 'Edit Profile';
  static const rollNumber = 'Roll Number';
  static const program = 'Program';
  static const currentYear = 'Current Year';
  static const cgpa = 'CGPA';
  static const specialization = 'Specialization';
  static const contactNumber = 'Contact Number';

  // Notifications.
  static const notifications = 'Notifications';

  // Resume.
  static const uploadResume = 'Upload Resume';
  static const choosePdfToUpload = 'Choose PDF to Upload';
  static const uploadHint = 'Maximum 2MB · PDF files only';
  static const browseFiles = 'Browse Files';
  static const resumeTemplates = 'Resume Templates';
  static const viewDetails = 'View Details';
  static const createNewResume = 'Create New Resume';
  static const createAndSaveResume = 'Create & Save Resume';

  // Errors / empty states.
  static const genericErrorTitle = 'Something went wrong';
  static const genericErrorMessage = 'Please try again in a moment.';
  static const retry = 'Retry';
  static const noDataTitle = 'Nothing here yet';
  static const noOpportunitiesMessage = 'Check back soon for new opportunities.';
  static const noNotificationsMessage = "You're all caught up.";
}

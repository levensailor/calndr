<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="settings-modal">
      <div class="modal-header">
        <h2>Settings</h2>
        <button class="close-button" @click="$emit('close')">&times;</button>
      </div>
      <div class="modal-content">
        <div class="tabs">
          <button 
            v-for="tab in tabs" 
            :key="tab" 
            :class="{ active: activeTab === tab }"
            @click="activeTab = tab"
          >
            {{ tab }}
          </button>
        </div>

        <div v-if="activeTab === 'Account'" class="tab-content">
          <h3>User Profile</h3>
          
          <!-- Profile Loading State -->
          <div v-if="profileLoading" class="profile-loading">
            <p>Loading profile...</p>
          </div>
          
          <!-- Profile Error State -->
          <div v-else-if="profileError" class="profile-error">
            <p class="error-message">Unable to load profile</p>
            <p class="error-details">{{ profileError }}</p>
            <div class="error-actions">
              <button @click="fetchUserProfile" class="retry-button">Retry</button>
              <button @click="showLoginModal = true" class="login-button" v-if="profileError.includes('authentication') || profileError.includes('token')">Login</button>
              <button @click="logout" class="logout-button">Logout</button>
            </div>
          </div>
          
          <!-- Profile Success State -->
          <div v-else-if="userProfile" class="profile-info">
            <div class="form-group">
              <label>Name</label>
              <p>{{ userProfile.first_name }} {{ userProfile.last_name }}</p>
            </div>
            <div class="form-group">
              <label>Email</label>
              <p>{{ userProfile.email }}</p>
            </div>
            <div class="form-group" v-if="userProfile.phone_number">
              <label>Phone</label>
              <p>{{ userProfile.phone_number }}</p>
            </div>
            <div class="form-group" v-if="userProfile.subscription_type">
              <label>Subscription</label>
              <p>{{ userProfile.subscription_type }} ({{ userProfile.subscription_status }})</p>
            </div>
            <div class="form-group" v-if="userProfile.created_at">
              <label>Member Since</label>
              <p>{{ formatDate(userProfile.created_at) }}</p>
            </div>
            <button @click="logout" class="logout-button">Logout</button>
          </div>
          
          <!-- No Profile State -->
          <div v-else class="profile-empty">
            <p>No profile information available</p>
            <div class="error-actions">
              <button @click="fetchUserProfile" class="retry-button">Load Profile</button>
              <button @click="showLoginModal = true" class="login-button">Login</button>
              <button @click="logout" class="logout-button">Logout</button>
            </div>
          </div>
        </div>

        <div v-if="activeTab === 'Appearance'" class="tab-content">
          <div class="form-group">
            <label>Theme</label>
            <div class="theme-selector">
              <div
                v-for="(theme, name) in themes"
                :key="name"
                class="theme-option"
                :class="{ active: currentTheme === name }"
                @click="$emit('set-theme', name)"
                @mouseenter="handleThemeMouseEnter(name)"
                @mouseleave="handleThemeMouseLeave()"
              >
                <div class="theme-preview" :style="getThemePreviewStyles(theme)">
                  <div class="preview-color" :style="{ backgroundColor: theme.colors.mainBg }"></div>
                  <div class="preview-color" :style="{ backgroundColor: theme.colors.jeff }"></div>
                  <div class="preview-color" :style="{ backgroundColor: theme.colors.deanna }"></div>
                </div>
                <span>{{ name }}</span>
                <div v-if="isCustomTheme(name) && hoveredThemeName === name" class="theme-actions">
                    <button @click.stop="editTheme(name)" class="action-button" title="Edit theme">
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path></svg>
                    </button>
                    <button @click.stop="deleteTheme(name)" class="action-button" title="Delete theme">
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                    </button>
                </div>
              </div>
              <div class="theme-option add-theme-option" @click="showThemeCreator = true">
                <div class="theme-preview">
                  <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <g id="Edit / Add_Plus">
                      <path id="Vector" d="M6 12H12M12 12H18M12 12V18M12 12V6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </g>
                  </svg>
                </div>
                <span>New</span>
              </div>
            </div>
          </div>
          <div class="form-group">
            <label class="toggle-label">
              <input type="checkbox" :checked="showIconLabels" @change="$emit('toggle-labels')">
              <span>Show Icon Labels in Footer</span>
            </label>
          </div>
        </div>

        <div v-if="activeTab === 'Notifications'" class="tab-content">
          <p>Manage email addresses for the weekly summary notification.</p>
          <ul class="email-list">
            <li v-for="email in emails" :key="email.id">
              <span>{{ email.email }}</span>
              <button @click="deleteEmail(email.id)" class="delete-button">&times;</button>
            </li>
          </ul>
          <div class="add-email-form">
            <input type="email" v-model="newEmail" placeholder="Add new email" @keyup.enter="addEmail">
            <button @click="addEmail">Add</button>
          </div>
        </div>

        <div v-if="activeTab === 'Security'" class="tab-content">
          <h3>Change App Password</h3>
          <div class="form-group">
              <label for="new-password">New Password</label>
              <input type="password" id="new-password" v-model="newPassword">
          </div>
          <div class="form-group">
              <label for="confirm-password">Confirm Password</label>
              <input type="password" id="confirm-password" v-model="confirmPassword">
          </div>
          <button @click="changePassword">Save Password</button>
        </div>
      </div>
    </div>
    <ThemeCreator 
      v-if="showThemeCreator"
      :existing-theme-names="Object.keys(themes)"
      :themeToEdit="themeToEdit"
      @cancel="cancelThemeCreation"
      @save="saveNewTheme"
    />
    
    <!-- Login Modal -->
    <div v-if="showLoginModal" class="modal-overlay" @click.self="showLoginModal = false">
      <div class="login-modal">
        <div class="modal-header">
          <h3>Login Required</h3>
          <button class="close-button" @click="showLoginModal = false">&times;</button>
        </div>
        <div class="modal-content">
          <p>Please login to access your profile information.</p>
          
          <div v-if="loginError" class="login-error">
            <p>{{ loginError }}</p>
          </div>
          
          <div class="form-group">
            <label for="login-email">Email</label>
            <input 
              type="email" 
              id="login-email" 
              v-model="loginEmail" 
              placeholder="Enter your email"
              :disabled="loginLoading"
              @keyup.enter="login"
            >
          </div>
          
          <div class="form-group">
            <label for="login-password">Password</label>
            <input 
              type="password" 
              id="login-password" 
              v-model="loginPassword" 
              placeholder="Enter your password"
              :disabled="loginLoading"
              @keyup.enter="login"
            >
          </div>
          
          <div class="login-actions">
            <button @click="login" :disabled="loginLoading" class="login-submit-button">
              {{ loginLoading ? 'Logging in...' : 'Login' }}
            </button>
            <button @click="switchToSignUp" class="signup-button">Sign Up</button>
            <button @click="showLoginModal = false" class="cancel-button">Cancel</button>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Sign Up Modal -->
    <div v-if="showSignUpModal" class="modal-overlay" @click.self="showSignUpModal = false">
      <div class="signup-modal">
        <div class="modal-header">
          <h3>Create Account</h3>
          <button class="close-button" @click="showSignUpModal = false">&times;</button>
        </div>
        <div class="modal-content">
          <p>Create a new account to get started.</p>
          
          <div v-if="signupError" class="signup-error">
            <p>{{ signupError }}</p>
          </div>
          
          <div class="form-group">
            <label for="signup-first-name">First Name</label>
            <input 
              type="text" 
              id="signup-first-name" 
              v-model="signupFirstName" 
              placeholder="Enter your first name"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-last-name">Last Name</label>
            <input 
              type="text" 
              id="signup-last-name" 
              v-model="signupLastName" 
              placeholder="Enter your last name"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-email">Email</label>
            <input 
              type="email" 
              id="signup-email" 
              v-model="signupEmail" 
              placeholder="Enter your email address"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-password">Password</label>
            <input 
              type="password" 
              id="signup-password" 
              v-model="signupPassword" 
              placeholder="Enter your password"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-confirm-password">Confirm Password</label>
            <input 
              type="password" 
              id="signup-confirm-password" 
              v-model="signupConfirmPassword" 
              placeholder="Confirm your password"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-phone">Phone Number (Optional)</label>
            <input 
              type="tel" 
              id="signup-phone" 
              v-model="signupPhoneNumber" 
              placeholder="Enter your phone number"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="form-group">
            <label for="signup-family-name">Family Name (Optional)</label>
            <input 
              type="text" 
              id="signup-family-name" 
              v-model="signupFamilyName" 
              placeholder="Enter your family name"
              :disabled="signupLoading"
            >
          </div>
          
          <div class="signup-actions">
            <button @click="signUp" :disabled="signupLoading" class="signup-submit-button">
              {{ signupLoading ? 'Creating Account...' : 'Create Account' }}
            </button>
            <button @click="switchToLogin" class="login-link-button">Already have an account? Login</button>
            <button @click="showSignUpModal = false" class="cancel-button">Cancel</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import ThemeCreator from './ThemeCreator.vue';

export default {
  name: 'SettingsModal',
  components: {
    ThemeCreator,
  },
  props: {
    themes: Object,
    currentTheme: String,
    showIconLabels: Boolean,
    backendThemes: Array,
  },
  emits: ['close', 'set-theme', 'toggle-labels', 'save-custom-theme', 'delete-custom-theme'],
  data() {
    return {
      activeTab: 'Account',
      tabs: ['Account', 'Appearance', 'Notifications', 'Security'],
      emails: [],
      newEmail: '',
      newPassword: '',
      confirmPassword: '',
      showThemeCreator: false,
      hoverTimeout: null,
      hoveredThemeName: null,
      editingThemeName: null,
      userProfile: null,
      profileLoading: false,
      profileError: null,
      showLoginModal: false,
      loginEmail: '',
      loginPassword: '',
      loginLoading: false,
      loginError: null,
      showSignUpModal: false,
      signupFirstName: '',
      signupLastName: '',
      signupEmail: '',
      signupPassword: '',
      signupConfirmPassword: '',
      signupPhoneNumber: '',
      signupFamilyName: '',
      signupLoading: false,
      signupError: null,
    };
  },
  computed: {
    themeToEdit() {
      if (!this.editingThemeName) return null;
      return {
        name: this.editingThemeName,
        ...this.themes[this.editingThemeName]
      };
    }
  },
  methods: {
    isCustomTheme(themeName) {
        // Check if it's a private theme that the user can edit/delete
        const themeData = this.themes[themeName];
        return themeData && themeData.isPublic === false;
    },
    handleThemeMouseEnter(themeName) {
        if (!this.isCustomTheme(themeName)) return;
        this.hoverTimeout = setTimeout(() => {
            this.hoveredThemeName = themeName;
        }, 2000);
    },
    handleThemeMouseLeave() {
        clearTimeout(this.hoverTimeout);
        this.hoveredThemeName = null;
    },
    deleteTheme(themeName) {
        if (confirm(`Are you sure you want to delete the theme "${themeName}"?`)) {
            this.$emit('delete-custom-theme', themeName);
            this.hoveredThemeName = null;
        }
    },
    async editTheme(themeName) {
        this.editingThemeName = themeName;
        this.showThemeCreator = true;
        this.hoveredThemeName = null;
    },
    
    async updateTheme(themeData) {
        try {
            const authToken = localStorage.getItem('authToken') || localStorage.getItem('jwtToken') || localStorage.getItem('accessToken');
            if (!authToken) {
                alert('Please login to edit themes');
                return;
            }

            const originalTheme = this.backendThemes.find(t => t.name === this.editingThemeName);
            if (!originalTheme) {
                console.error('Original theme not found');
                return;
            }

            if (originalTheme.is_public) {
                alert('Cannot edit public themes');
                return;
            }

            const themePayload = {
                name: themeData.name,
                mainBackgroundColor: themeData.colors.mainBg,
                secondaryBackgroundColor: themeData.colors.headerBg,
                textColor: themeData.colors.textColor,
                headerTextColor: themeData.colors.editableTextColor,
                iconColor: themeData.colors.iconColor,
                iconActiveColor: themeData.colors.iconActive,
                accentColor: themeData.colors.todayBorder,
                parentOneColor: themeData.colors.jeff,
                parentTwoColor: themeData.colors.deanna,
                is_public: false
            };

            await axios.put(`/themes/${originalTheme.id}`, themePayload, {
                headers: { 'Authorization': `Bearer ${authToken}` }
            });
            
            // Emit event to refresh themes in parent component
            this.$emit('save-custom-theme', themeData);
            
            console.log('Theme updated successfully');
            
        } catch (error) {
            console.error('Error updating theme:', error);
            alert('Failed to update theme. Please try again.');
        }
    },
    getThemePreviewStyles(theme) {
      return {
        color: theme.colors.textColor,
      };
    },
    async fetchEmails() {
      try {
        const response = await axios.get('/notifications/emails');
        this.emails = response.data;
      } catch (error) {
        console.error('Error fetching notification emails:', error);
      }
    },
    async addEmail() {
      if (this.newEmail && this.newEmail.includes('@')) {
        try {
          const response = await axios.post('/notifications/emails', { email: this.newEmail });
          this.emails.push(response.data);
          this.newEmail = '';
        } catch (error) {
          console.error('Error adding email:', error);
          alert('Failed to add email. It might already exist.');
        }
      }
    },
    async deleteEmail(id) {
      try {
        await axios.delete(`/notifications/emails/${id}`);
        this.emails = this.emails.filter(e => e.id !== id);
      } catch (error) {
        console.error('Error deleting email:', error);
      }
    },
    changePassword() {
      if (this.newPassword && this.newPassword === this.confirmPassword) {
        alert('Password changed successfully (feature is mocked).');
        this.newPassword = '';
        this.confirmPassword = '';
      } else {
        alert('Passwords do not match.');
      }
    },
    saveNewTheme(themeData) {
      if (this.editingThemeName) {
        // Editing existing theme
        this.updateTheme(themeData);
      } else {
        // Creating new theme
        this.$emit('save-custom-theme', themeData);
      }
      this.showThemeCreator = false;
      this.editingThemeName = null;
    },
    cancelThemeCreation() {
      this.showThemeCreator = false;
      this.editingThemeName = null;
    },
    async fetchUserProfile() {
      this.profileLoading = true;
      this.profileError = null;
      
      try {
        // Check if we have an authentication token
        const authToken = localStorage.getItem('authToken') || localStorage.getItem('jwtToken') || localStorage.getItem('accessToken');
        
        if (!authToken) {
          this.profileError = 'No authentication token found. Please login to view your profile.';
          this.profileLoading = false;
          return;
        }
        
        // Set the authorization header for this request
        const headers = {
          'Authorization': `Bearer ${authToken}`
        };
        
        const response = await axios.get('/user/profile', { headers });
        this.userProfile = response.data;
        console.log('Profile loaded successfully:', this.userProfile);
      } catch (error) {
        console.error('Error fetching user profile:', error);
        
        if (error.response && error.response.status === 401) {
          this.profileError = 'Authentication failed. Your session may have expired.';
        } else if (error.response && error.response.status === 404) {
          this.profileError = 'User profile not found.';
        } else if (error.response) {
          this.profileError = `Server error (${error.response.status}): ${error.response.data?.detail || error.response.statusText}`;
        } else {
          this.profileError = error.message || 'Failed to load profile. Please check your connection.';
        }
      } finally {
        this.profileLoading = false;
      }
    },
    logout() {
      if (confirm('Are you sure you want to logout?')) {
        // Clear any stored authentication tokens and session data
        localStorage.removeItem('authToken');
        localStorage.removeItem('jwtToken');
        localStorage.removeItem('accessToken');
        localStorage.removeItem('lastSuccessfulLogin');
        localStorage.removeItem('loginAttempts');
        localStorage.removeItem('lockoutEndTime');
        
        // Clear axios default headers
        delete axios.defaults.headers.common['Authorization'];
        
        // Reload the page to reset the app state and return to lock screen
        window.location.reload();
      }
    },
    async login() {
      if (!this.loginEmail || !this.loginPassword) {
        this.loginError = 'Please enter both email and password.';
        return;
      }
      
      this.loginLoading = true;
      this.loginError = null;
      
      try {
        // Create form data for the OAuth2 token endpoint
        const formData = new URLSearchParams();
        formData.append('username', this.loginEmail);
        formData.append('password', this.loginPassword);
        
        const response = await axios.post('/auth/token', formData, {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          }
        });
        
        const { access_token } = response.data;
        
        // Store the token
        localStorage.setItem('authToken', access_token);
        
        // Set default authorization header for future requests
        axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
        
        // Close login modal and reset form
        this.showLoginModal = false;
        this.loginEmail = '';
        this.loginPassword = '';
        this.loginError = null;
        
        // Fetch the user profile now that we're authenticated
        this.fetchUserProfile();
        
      } catch (error) {
        console.error('Login error:', error);
        
        if (error.response && error.response.status === 401) {
          this.loginError = 'Invalid email or password.';
        } else if (error.response) {
          this.loginError = `Login failed: ${error.response.data?.detail || error.response.statusText}`;
        } else {
          this.loginError = 'Login failed. Please check your connection and try again.';
        }
      } finally {
        this.loginLoading = false;
      }
    },
    switchToSignUp() {
      this.showLoginModal = false;
      this.showSignUpModal = true;
      this.loginError = null;
      this.signupError = null;
    },
    switchToLogin() {
      this.showSignUpModal = false;
      this.showLoginModal = true;
      this.signupError = null;
      this.loginError = null;
    },
    async signUp() {
      // Validate inputs
      if (!this.signupFirstName.trim() || !this.signupLastName.trim() || !this.signupEmail.trim() || !this.signupPassword) {
        this.signupError = 'Please fill in all required fields.';
        return;
      }
      
      if (this.signupPassword !== this.signupConfirmPassword) {
        this.signupError = 'Passwords do not match.';
        return;
      }
      
      if (this.signupPassword.length < 6) {
        this.signupError = 'Password must be at least 6 characters long.';
        return;
      }
      
      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(this.signupEmail.trim())) {
        this.signupError = 'Please enter a valid email address.';
        return;
      }
      
      this.signupLoading = true;
      this.signupError = null;
      
      try {
        const registrationData = {
          first_name: this.signupFirstName.trim(),
          last_name: this.signupLastName.trim(),
          email: this.signupEmail.trim(),
          password: this.signupPassword,
          phone_number: this.signupPhoneNumber.trim() || null,
          family_name: this.signupFamilyName.trim() || null
        };
        
        const response = await axios.post('/auth/register', registrationData);
        
        const { access_token } = response.data;
        
        // Store the token
        localStorage.setItem('authToken', access_token);
        
        // Set default authorization header for future requests
        axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
        
        // Close signup modal and reset form
        this.showSignUpModal = false;
        this.resetSignupForm();
        
        // Fetch the user profile now that we're authenticated
        this.fetchUserProfile();
        
      } catch (error) {
        console.error('Signup error:', error);
        
        if (error.response && error.response.status === 409) {
          this.signupError = 'An account with this email already exists.';
        } else if (error.response) {
          this.signupError = `Registration failed: ${error.response.data?.detail || error.response.statusText}`;
        } else {
          this.signupError = 'Registration failed. Please check your connection and try again.';
        }
      } finally {
        this.signupLoading = false;
      }
    },
    resetSignupForm() {
      this.signupFirstName = '';
      this.signupLastName = '';
      this.signupEmail = '';
      this.signupPassword = '';
      this.signupConfirmPassword = '';
      this.signupPhoneNumber = '';
      this.signupFamilyName = '';
      this.signupError = null;
    },
    formatDate(dateString) {
      if (!dateString) return '';
      try {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'long',
          day: 'numeric'
        });
      } catch (error) {
        return dateString;
      }
    }
  },
  created() {
    this.fetchEmails();
    this.fetchUserProfile();
  },
};
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.settings-modal {
  background: white;
  color: #333;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 20px;
  border-bottom: 1px solid #eee;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
}

.close-button {
  background: none;
  border: none;
  font-size: 1.75rem;
  cursor: pointer;
  line-height: 1;
}

.modal-content {
  padding: 20px;
  overflow-y: auto;
}

.tabs {
  display: flex;
  border-bottom: 1px solid #ccc;
  margin-bottom: 20px;
}

.tabs button {
  padding: 10px 20px;
  border: none;
  background: none;
  cursor: pointer;
  border-bottom: 3px solid transparent;
  margin-bottom: -1px;
}

.tabs button.active {
  border-bottom-color: #007bff;
  font-weight: bold;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: 500;
}

.form-group input[type="text"],
.form-group input[type="email"],
.form-group input[type="password"],
.form-group select {
  width: 100%;
  padding: 10px;
  border: 1px solid #ccc;
  border-radius: 4px;
}

.theme-selector {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
  gap: 15px;
  margin-top: 5px;
}

.theme-option {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 8px;
  border-radius: 6px;
  border: 2px solid transparent;
  transition: all 0.2s;
  text-align: center;
  position: relative;
}

.theme-option span {
    font-size: 12px;
    word-break: break-word;
}

.theme-option.active {
  border-color: #007bff;
  background-color: #f0f8ff;
}

.theme-option .theme-preview {
  width: 100%;
  height: 40px;
  border-radius: 4px;
  border: 1px solid #ccc;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  margin-bottom: 5px;
}

.theme-preview .preview-color {
  width: 100%;
  height: 100%;
}

.theme-option.add-theme-option .theme-preview {
  flex-direction: row;
  display: flex;
  justify-content: center;
  align-items: center;
  color: #ccc;
  background-color: #f9f9f9;
}

.add-theme-option .theme-preview svg {
  width: 30px;
  height: 30px;
}

.add-theme-option:hover {
  background-color: #f0f0f0;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
}

.email-list {
  list-style: none;
  padding: 0;
  margin-bottom: 15px;
}

.email-list li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  border-radius: 4px;
}

.email-list li:nth-child(odd) {
  background-color: #f9f9f9;
}

.delete-button {
  background: none;
  border: none;
  color: #d9534f;
  font-size: 1.2rem;
  font-weight: bold;
  cursor: pointer;
}

.add-email-form {
  display: flex;
  gap: 10px;
}

.add-email-form input {
  flex-grow: 1;
}

.profile-loading {
  text-align: center;
  padding: 20px;
  color: #666;
}

.profile-error {
  text-align: center;
  padding: 20px;
}

.error-message {
  color: #d9534f;
  font-weight: 500;
  margin-bottom: 10px;
}

.error-details {
  color: #666;
  font-size: 14px;
  margin-bottom: 15px;
}

.error-actions {
  display: flex;
  gap: 10px;
  justify-content: center;
}

.retry-button {
  background-color: #007bff;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.retry-button:hover {
  background-color: #0056b3;
}

.logout-button {
  background-color: #dc3545;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.logout-button:hover {
  background-color: #c82333;
}

.login-button {
  background-color: #28a745;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.login-button:hover {
  background-color: #218838;
}

.profile-info .form-group p {
  margin: 0;
  padding: 8px;
  background-color: #f8f9fa;
  border-radius: 4px;
  border: 1px solid #e9ecef;
}

.profile-empty {
  text-align: center;
  padding: 20px;
  color: #666;
}

.login-modal {
  background: white;
  color: #333;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
  width: 90%;
  max-width: 400px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.login-error {
  background-color: #f8d7da;
  color: #721c24;
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 15px;
  border: 1px solid #f5c6cb;
}

.login-actions {
  display: flex;
  gap: 10px;
  justify-content: flex-end;
  margin-top: 20px;
}

.login-submit-button {
  background-color: #007bff;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.login-submit-button:hover:not(:disabled) {
  background-color: #0056b3;
}

.login-submit-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}

.cancel-button {
  background-color: #6c757d;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.cancel-button:hover {
  background-color: #5a6268;
}

.theme-actions {
  position: absolute;
  top: 5px;
  right: 5px;
  display: flex;
  gap: 5px;
  background-color: rgba(255, 255, 255, 0.8);
  padding: 3px;
  border-radius: 5px;
}

.action-button {
  background: none;
  border: none;
  cursor: pointer;
  padding: 2px;
}

.action-button svg {
  width: 16px;
  height: 16px;
  stroke: #333;
}

.action-button:hover svg {
  stroke: #007bff;
}

/* ====== MOBILE OPTIMIZATIONS ====== */
@media (max-width: 768px) {
  .settings-modal {
    width: 95%;
    max-width: none;
    max-height: 95vh;
    margin: 10px;
  }

  .modal-header {
    padding: 12px 15px;
  }

  .modal-header h2 {
    font-size: 1.1rem;
  }

  .close-button {
    font-size: 1.5rem;
    padding: 5px;
    min-width: 44px; /* iOS touch target size */
    min-height: 44px;
  }

  .modal-content {
    padding: 15px;
  }

  .tabs {
    margin-bottom: 15px;
    flex-wrap: wrap;
  }

  .tabs button {
    padding: 8px 15px;
    min-width: 44px;
    min-height: 44px;
    font-size: 14px;
  }

  .theme-selector {
    grid-template-columns: repeat(auto-fill, minmax(70px, 1fr));
    gap: 10px;
  }

  .theme-option {
    padding: 6px;
    min-width: 44px;
    min-height: 44px;
  }

  .theme-option span {
    font-size: 11px;
  }

  .theme-option .theme-preview {
    height: 35px;
    margin-bottom: 3px;
  }

  .form-group input[type="text"],
  .form-group input[type="email"],
  .form-group input[type="password"],
  .form-group select {
    padding: 12px;
    font-size: 16px; /* Prevents zoom on iOS */
    border-radius: 6px;
  }

  .toggle-label {
    gap: 8px;
    min-height: 44px;
    align-items: center;
  }

  .email-list li {
    padding: 10px;
    min-height: 44px;
  }

  .delete-button {
    font-size: 1.1rem;
    padding: 5px;
    min-width: 44px;
    min-height: 44px;
  }

  .add-email-form {
    flex-direction: column;
    gap: 8px;
  }

  .add-email-form input {
    margin-bottom: 0;
  }

  .error-actions {
    flex-direction: column;
    gap: 8px;
  }

  .retry-button,
  .logout-button,
  .login-button {
    padding: 12px 16px;
    font-size: 16px;
    min-height: 44px;
    touch-action: manipulation;
  }

  .login-modal {
    width: 95%;
    max-width: none;
    margin: 10px;
  }

  .login-actions {
    flex-direction: column;
    gap: 8px;
  }

  .login-submit-button,
  .cancel-button {
    padding: 12px 16px;
    font-size: 16px;
    min-height: 44px;
    touch-action: manipulation;
  }

  .theme-actions {
    top: 3px;
    right: 3px;
    padding: 2px;
  }

  .action-button {
    padding: 4px;
    min-width: 32px;
    min-height: 32px;
  }

  .action-button svg {
    width: 14px;
    height: 14px;
  }
}

@media (max-width: 480px) {
  .settings-modal {
    width: 98%;
    margin: 5px;
  }

  .modal-header {
    padding: 10px 12px;
  }

  .modal-header h2 {
    font-size: 1rem;
  }

  .modal-content {
    padding: 12px;
  }

  .tabs button {
    padding: 6px 12px;
    font-size: 13px;
  }

  .theme-selector {
    grid-template-columns: repeat(auto-fill, minmax(60px, 1fr));
    gap: 8px;
  }

  .theme-option {
    padding: 4px;
  }

  .theme-option span {
    font-size: 10px;
  }

  .theme-option .theme-preview {
    height: 30px;
  }

  .form-group {
    margin-bottom: 12px;
  }

  .form-group label {
    font-size: 14px;
  }
}

/* Touch-friendly improvements */
@media (pointer: coarse) {
  .theme-option {
    touch-action: manipulation;
  }

  .close-button {
    touch-action: manipulation;
  }

  .tabs button {
    touch-action: manipulation;
  }

  .delete-button {
    touch-action: manipulation;
  }

  .action-button {
    touch-action: manipulation;
  }
}

/* Signup Modal Styles */
.signup-modal {
  background: white;
  color: #333;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
}

.signup-error {
  background-color: #f8d7da;
  color: #721c24;
  padding: 10px;
  border-radius: 4px;
  margin-bottom: 15px;
  border: 1px solid #f5c6cb;
}

.signup-actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 20px;
}

.signup-submit-button {
  background-color: #28a745;
  color: white;
  border: none;
  padding: 12px 20px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 500;
}

.signup-submit-button:hover:not(:disabled) {
  background-color: #218838;
}

.signup-submit-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}

.signup-button {
  background-color: #28a745;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.signup-button:hover {
  background-color: #218838;
}

.login-link-button {
  background: none;
  border: none;
  color: #007bff;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  text-decoration: underline;
}

.login-link-button:hover {
  color: #0056b3;
}

/* Mobile optimizations for signup modal */
@media (max-width: 768px) {
  .signup-modal {
    width: 95%;
    max-width: none;
    margin: 10px;
  }
  
  .signup-actions {
    gap: 8px;
  }
  
  .signup-submit-button,
  .login-link-button,
  .signup-button {
    padding: 12px 16px;
    font-size: 16px;
    min-height: 44px;
    touch-action: manipulation;
  }
}
</style> 
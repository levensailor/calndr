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
    customThemeNames: Array,
  },
  emits: ['close', 'set-theme', 'toggle-labels', 'save-custom-theme', 'delete-custom-theme'],
  data() {
    return {
      activeTab: 'Appearance',
      tabs: ['Appearance', 'Notifications', 'Security'],
      emails: [],
      newEmail: '',
      newPassword: '',
      confirmPassword: '',
      showThemeCreator: false,
      hoverTimeout: null,
      hoveredThemeName: null,
      editingThemeName: null,
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
        return this.customThemeNames.includes(themeName);
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
    editTheme(themeName) {
        this.editingThemeName = themeName;
        this.showThemeCreator = true;
        this.hoveredThemeName = null;
    },
    getThemePreviewStyles(theme) {
      return {
        color: theme.colors.textColor,
      };
    },
    async fetchEmails() {
      try {
        const response = await axios.get('/api/notifications/emails');
        this.emails = response.data;
      } catch (error) {
        console.error('Error fetching notification emails:', error);
      }
    },
    async addEmail() {
      if (this.newEmail && this.newEmail.includes('@')) {
        try {
          const response = await axios.post('/api/notifications/emails', { email: this.newEmail });
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
        await axios.delete(`/api/notifications/emails/${id}`);
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
      this.$emit('save-custom-theme', themeData);
      this.showThemeCreator = false;
      this.editingThemeName = null;
    },
    cancelThemeCreation() {
      this.showThemeCreator = false;
      this.editingThemeName = null;
    }
  },
  created() {
    this.fetchEmails();
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
</style> 
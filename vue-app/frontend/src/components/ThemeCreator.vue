<template>
  <div class="modal-overlay" @click.self="$emit('cancel')">
    <div class="theme-creator-modal" :style="modalStyle">
      <h3 class="modal-title">{{ isEditing ? 'Edit Theme' : 'Create New Theme' }}</h3>
      
      <div class="form-group">
        <label for="themeName">Theme Name</label>
        <input type="text" id="themeName" v-model="newTheme.name" placeholder="e.g., Ocean Breeze">
        <p v-if="nameError" class="error-text">{{ nameError }}</p>
      </div>

      <div class="form-group">
        <label for="font-select">Font Family</label>
        <select id="font-select" v-model="newTheme.font">
          <option v-for="font in fonts" :key="font.name" :value="font.value">{{ font.name }}</option>
        </select>
      </div>

      <div class="color-pickers-grid">
        <div v-for="color in colorVariables" :key="color.key" class="color-picker-group">
          <label :for="`color-${color.key}`">{{ color.label }}</label>
          <div class="color-input-wrapper">
            <input type="color" :id="`color-${color.key}`" v-model="newTheme.colors[color.key]">
            <span>{{ newTheme.colors[color.key] }}</span>
          </div>
        </div>
      </div>
      
      <div class="modal-actions">
        <button class="button-secondary" @click="$emit('cancel')">Cancel</button>
        <button class="button-primary" @click="saveTheme">Save Theme</button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ThemeCreator',
  props: {
    existingThemeNames: {
      type: Array,
      default: () => [],
    },
    themeToEdit: {
      type: Object,
      default: null,
    },
  },
  emits: ['save', 'cancel'],
  data() {
    return {
      nameError: '',
      newTheme: {
        name: '',
        font: "'-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'sans-serif'",
        colors: {
          jeff: '#96CBFC',
          deanna: '#FFC2D9',
          todayBorder: '#2a64c4',
          otherMonthBg: '#f7f7f7',
          otherMonthColor: '#aaaaaa',
          mainBg: '#ffffff',
          textColor: '#000000',
          editableTextColor: '#000000',
          gridLines: '#979797',
          headerBg: '#e0e0e0',
          footerBg: '#f0f0f0',
          iconColor: '#555555',
          iconActive: '#007bff',
        },
      },
      fonts: [
        { name: 'System Default', value: "'-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'sans-serif'" },
        { name: 'Comic Sans MS', value: "'Comic Sans MS', 'Chalkboard SE', sans-serif" },
        { name: 'Dancing Script', value: "'Dancing Script', cursive" },
        { name: 'Fira Code', value: "'Fira Code', monospace" },
        { name: 'Inconsolata', value: "'Inconsolata', monospace" },
        { name: 'Inter', value: "'Inter', sans-serif" },
        { name: 'Lato', value: "'Lato', sans-serif" },
        { name: 'Libre Franklin', value: "'Libre Franklin', sans-serif" },
        { name: 'Lora', value: "'Lora', serif" },
        { name: 'Poppins', value: "'Poppins', sans-serif" },
        { name: 'Raleway', value: "'Raleway', sans-serif" },
        { name: 'Roboto', value: "'Roboto', sans-serif" },
        { name: 'Rubik', value: "'Rubik', sans-serif" },
      ],
      colorVariables: [
        { key: 'jeff', label: 'Jeff Custody' },
        { key: 'deanna', label: 'Deanna Custody' },
        { key: 'todayBorder', label: 'Today Border' },
        { key: 'otherMonthBg', label: 'Other Month BG' },
        { key: 'otherMonthColor', label: 'Other Month Text' },
        { key: 'mainBg', label: 'Main Background' },
        { key: 'textColor', label: 'Main Text' },
        { key: 'editableTextColor', label: 'Editable Text' },
        { key: 'gridLines', label: 'Grid Lines' },
        { key: 'headerBg', label: 'Header BG' },
        { key: 'footerBg', label: 'Footer BG' },
        { key: 'iconColor', label: 'Icon' },
        { key: 'iconActive', label: 'Icon Active' },
      ],
    };
  },
  watch: {
    themeToEdit: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          this.newTheme.name = newVal.name;
          this.newTheme.font = newVal.font;
          this.newTheme.colors = JSON.parse(JSON.stringify(newVal.colors));
        } else {
          this.resetForm();
        }
      },
    },
  },
  computed: {
    isEditing() {
      return !!this.themeToEdit;
    },
    modalStyle() {
        if (this.isEditing) {
            return {
                fontFamily: this.newTheme.font,
            };
        }
        return {};
    }
  },
  methods: {
    saveTheme() {
      this.nameError = '';
      if (!this.newTheme.name.trim()) {
        this.nameError = 'Theme name cannot be empty.';
        return;
      }
      
      const isNameTaken = this.existingThemeNames.includes(this.newTheme.name) && (!this.isEditing || this.newTheme.name !== this.themeToEdit.name);

      if (isNameTaken) {
        this.nameError = 'This theme name already exists.';
        return;
      }

      this.$emit('save', this.newTheme);
    },
    resetForm() {
      this.newTheme.name = '';
      this.newTheme.font = "'-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'sans-serif'";
      this.newTheme.colors = {
        jeff: '#96CBFC',
        deanna: '#FFC2D9',
        todayBorder: '#2a64c4',
        otherMonthBg: '#f7f7f7',
        otherMonthColor: '#aaaaaa',
        mainBg: '#ffffff',
        textColor: '#000000',
        editableTextColor: '#000000',
        gridLines: '#979797',
        headerBg: '#e0e0e0',
        footerBg: '#f0f0f0',
        iconColor: '#555555',
        iconActive: '#007bff',
      };
      this.nameError = '';
    },
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.6);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1001;
}

.theme-creator-modal {
  background-color: #fff;
  padding: 25px;
  border-radius: 8px;
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.3);
  width: 90%;
  max-width: 600px;
  color: #333;
}

.modal-title {
  margin-top: 0;
  margin-bottom: 20px;
  color: #111;
  text-align: center;
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
.form-group select {
  width: 100%;
  padding: 8px;
  border: 1px solid #ccc;
  border-radius: 4px;
}

.error-text {
  color: #d9534f;
  font-size: 12px;
  margin-top: 5px;
}

.color-pickers-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 15px;
  margin-top: 20px;
  margin-bottom: 20px;
}

.color-picker-group label {
  font-size: 14px;
  margin-bottom: 5px;
  display: block;
}

.color-input-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.color-input-wrapper input[type="color"] {
  width: 30px;
  height: 30px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  padding: 0;
}

.color-input-wrapper span {
  font-family: monospace;
  font-size: 14px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 25px;
}

.button-primary, .button-secondary {
  padding: 10px 20px;
  border-radius: 5px;
  border: none;
  cursor: pointer;
  font-weight: bold;
}

.button-primary {
  background-color: #007bff;
  color: white;
}

.button-secondary {
  background-color: #6c757d;
  color: white;
}
</style> 
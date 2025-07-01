<template>
  <div class="calendar-container">
    <div class="calendar" :style="themeStyles">
      <div class="calendar-header">
        <div class="day-name" v-for="day in daysOfWeek" :key="day">{{ day }}</div>
      </div>
      <div class="calendar-grid">
        <div 
          class="day-cell" 
          v-for="day in calendarDays" 
          :key="day.date" 
          :class="{ 'other-month': !day.isCurrentMonth, 'is-today': day.date === todayIsoDate }"
        >
          <WeatherFX
            v-if="showRaindrops"
            :cloud-cover="getCloudCover(day.date)"
            :precipitation="getPrecipitationChance(day.date)"
          />
          <div class="day-header-icons">
            <div class="wave-info" v-if="showWaves && getWaveInfo(day.date).count > 0">
              <svg v-for="n in getWaveInfo(day.date).count" :key="n" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12h2.5c1 0 1.5-1.5 2.5-1.5s1.5 1.5 2.5 1.5s1.5-1.5 2.5-1.5s1.5 1.5 2.5 1.5s1.5-1.5 2.5-1.5H21"/></svg>
              <span>{{ getWaveInfo(day.date).text }}</span>
            </div>
            <div class="school-event-info" v-if="showSchoolEvents && getSchoolEvent(day.date)">
              <svg class="school-event-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M12,3L1,9L12,15L23,9L12,3M5,13.18V17.18L12,21L19,17.18V13.18L12,17L5,13.18Z" /></svg>
              <span>{{ getSchoolEvent(day.date) }}</span>
            </div>
            <div class="temp-info" v-if="showRaindrops && getTemperature(day.date) !== null">
               <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.5 4.5C14.5 3.11929 13.3807 2 12 2C10.6193 2 9.5 3.11929 9.5 4.5V13.7578C8.29401 14.565 7.5 15.9398 7.5 17.5C7.5 19.9853 9.51472 22 12 22C14.4853 22 16.5 19.9853 16.5 17.5C16.5 15.9398 15.706 14.565 14.5 13.7578V4.5Z" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M12 18.5C12.5523 18.5 13 18.0523 13 17.5C13 16.9477 12.5523 16.5 12 16.5C11.4477 16.5 11 16.9477 11 17.5C11 18.0523 11.4477 18.5 12 18.5Z" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
              <span>{{ getTemperature(day.date) }}&deg;F</span>
            </div>
          </div>
          <div class="day-number">{{ day.day }}</div>
          <div class="events">
            <div
              v-for="n in 4"
              :key="n"
              class="event-placeholder"
              contenteditable="true"
              @focus="handleFocus($event.target)"
              @blur="handleBlur($event, day.date, n - 1)"
              @keydown.enter.prevent="$event.target.blur()"
              :ref="el => setEventRef(el, day.date, n - 1)"
              v-html="getEventContent(day.date, n - 1)"
            ></div>
            <div
              class="event-placeholder custody-row"
              :class="getCustodyInfo(day.date).class"
              @click="toggleCustody(day.date)"
            >
              <svg class="child-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M16,12V4H17V2H7V4H8V12L6,14V16H11.5V22H12.5V16H18V14L16,12Z" />
              </svg>
              <span>{{ getCustodyInfo(day.date).text }}</span>
            </div>
          </div>
        </div>
      </div>
      <div class="calendar-footer">
        <div class="footer-icons">
          <button @click="toggleRaindrops" class="icon-button" title="Toggle Weather">
            <svg :class="{ 'active': showRaindrops }" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="16" y1="13" x2="16" y2="21"></line><line x1="8" y1="13" x2="8" y2="21"></line><line x1="12" y1="15" x2="12" y2="23"></line><path d="M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25"></path>
            </svg>
            <span v-if="showIconLabels" class="icon-label">Weather</span>
          </button>
          <button @click="toggleWaves" class="icon-button surfboard-toggle" title="Toggle Waves">
            <svg :class="{ 'active': showWaves }" width="24" height="24" viewBox="0 -2 20 20" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="2">
              <g transform="translate(-2 -4)">
                <path d="M21,11c-2.25,0-2.25,2-4.5,2s-2.25-2-4.5-2-2.25,2-4.5,2S5.25,11,3,11"/>
                <path d="M3,5C5.25,5,5.25,7,7.5,7S9.75,5,12,5s2.26,2,4.51,2S18.75,5,21,5"/>
                <path d="M21,17c-2.25,0-2.25,2-4.5,2s-2.25-2-4.5-2-2.25,2-4.5,2S5.25,17,3,17"/>
              </g>
            </svg>
            <span v-if="showIconLabels" class="icon-label">Waves</span>
          </button>
          <button @click="toggleSchoolEvents" class="icon-button" title="Toggle Daycare Events">
            <svg :class="{ 'active': showSchoolEvents }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M12,3L1,9L12,15L23,9L12,3M5,13.18V17.18L12,21L19,17.18V13.18L12,17L5,13.18Z" />
            </svg>
            <span v-if="showIconLabels" class="icon-label">Daycare</span>
          </button>
        </div>
        <div class="month-nav">
          <button @click="prevMonth" class="icon-button">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
          </button>
          <span>{{ currentMonthName }} {{ currentYear }}</span>
          <button @click="nextMonth" class="icon-button">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
          </button>
          <div class="custody-share">
            {{ custodianOne ? custodianOne.first_name : 'Jeff' }} {{ custodyShare.jeff }}% | ({{ custodyStreak }}) | {{ custodianTwo ? custodianTwo.first_name : 'Deanna' }} {{ custodyShare.deanna }}%
          </div>
        </div>
        <div class="footer-actions">
          <button @click="sendSummary" class="icon-button" title="Send Email Summary">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round">
              <path stroke="none" d="M0 0h24v24H0z" fill="none"/>
              <rect x="3" y="5" width="18" height="14" rx="2" />
              <polyline points="3 7 12 13 21 7" />
            </svg>
            <span v-if="showIconLabels" class="icon-label">Email</span>
          </button>
          <button @click="toggleSettingsModal" class="icon-button" title="Settings">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z" />
              <path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
            </svg>
            <span v-if="showIconLabels" class="icon-label">Settings</span>
          </button>
        </div>
      </div>
    </div>
    <SettingsModal 
      v-if="showSettingsModal" 
      @close="toggleSettingsModal"
      :themes="allThemes"
      :currentTheme="currentTheme"
      :customThemeNames="Object.keys(customThemes)"
      @set-theme="setTheme"
      :showIconLabels="showIconLabels"
      @toggle-labels="toggleIconLabels"
      @save-custom-theme="saveCustomTheme"
      @delete-custom-theme="deleteCustomTheme"
    />
  </div>
</template>

<script>
import axios from 'axios';
import WeatherFX from './WeatherFX.vue';
import SettingsModal from './SettingsModal.vue';

export default {
  name: 'Calendar',
  components: {
    WeatherFX,
    SettingsModal,
  },
  data() {
    console.log("Calendar.vue: data() called");
    return {
      currentDate: new Date(),
      daysOfWeek: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      events: {},
      eventRefs: {},
      weather: {},
      waves: {},
      schoolEvents: {},
      showRaindrops: localStorage.getItem('showRaindrops') === 'true',
      showWaves: localStorage.getItem('showWaves') === 'true',
      showSchoolEvents: localStorage.getItem('showSchoolEvents') === 'true',
      showIconLabels: localStorage.getItem('showIconLabels') === 'true',
      showSettingsModal: false,
      currentTheme: 'Stork',
      themes: {
        Stork: {
          font: "'-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', 'sans-serif'",
          colors: {
            jeff: '#96CBFC',
            deanna: '#FFC2D9',
            todayBorder: '#2a64c4',
            otherMonthBg: '#f7f7f7',
            otherMonthColor: '#aaa',
            mainBg: '#fff',
            textColor: '#000',
            editableTextColor: '#000',
            gridLines: '#979797',
            headerBg: '#e0e0e0',
            footerBg: '#f0f0f0',
            iconColor: '#555',
            iconActive: '#007bff',
          },
        },
        Dracula: {
          font: "'Fira Code', monospace",
          colors: {
            jeff: '#44475a',
            deanna: '#6272a4',
            todayBorder: '#ff79c6',
            otherMonthBg: '#21222c',
            otherMonthColor: '#6272a4',
            mainBg: '#282a36',
            textColor: '#f8f8f2',
            editableTextColor: '#ff79c6',
            gridLines: '#44475a',
            headerBg: '#191a21',
            footerBg: '#191a21',
            iconColor: '#bd93f9',
            iconActive: '#ff79c6',
          },
        },
        Vibe: {
          font: "'Inter', sans-serif",
          colors: {
            jeff: '#3b2d60',
            deanna: '#5d4a9c',
            todayBorder: '#00fddc',
            otherMonthBg: '#1a103c',
            otherMonthColor: '#5d4a9c',
            mainBg: '#251758',
            textColor: '#e0d8ff',
            editableTextColor: '#ffffff',
            gridLines: '#3b2d60',
            headerBg: '#12092a',
            footerBg: '#12092a',
            iconColor: '#b3a5ef',
            iconActive: '#00fddc',
          },
        },
        Sunshine: {
          font: "'Poppins', sans-serif",
          colors: {
            jeff: '#89cff0',
            deanna: '#ffb347',
            todayBorder: '#ff6347',
            otherMonthBg: '#fff8e1',
            otherMonthColor: '#ccc',
            mainBg: '#fffff0',
            textColor: '#5d4037',
            editableTextColor: '#ffffff',
            gridLines: '#ffd54f',
            headerBg: '#ffecb3',
            footerBg: '#ffecb3',
            iconColor: '#8d6e63',
            iconActive: '#ff6347',
          },
        },
        Crayola: {
          font: "'Comic Sans MS', 'Chalkboard SE', sans-serif",
          colors: {
            jeff: '#4682b4',
            deanna: '#ff69b4',
            todayBorder: '#32cd32',
            otherMonthBg: '#f0f8ff',
            otherMonthColor: '#d3d3d3',
            mainBg: '#fff',
            textColor: '#000',
            editableTextColor: '#ffffff',
            gridLines: '#b0c4de',
            headerBg: '#ffd700',
            footerBg: '#ff7f50',
            iconColor: '#000',
            iconActive: '#1e90ff',
          },
        },
        Princess: {
          font: "'Dancing Script', cursive",
          colors: {
            jeff: '#e0bbee',
            deanna: '#ffb6c1',
            todayBorder: '#ffd700',
            otherMonthBg: '#fdf4f5',
            otherMonthColor: '#d8bfd8',
            mainBg: '#fffafb',
            textColor: '#5e3c58',
            editableTextColor: '#ffffff',
            gridLines: '#f1e4f2',
            headerBg: '#fae3f5',
            footerBg: '#fae3f5',
            iconColor: '#c789a8',
            iconActive: '#e6a4b4',
          },
        },
      },
      customThemes: {}, // This will hold themes from localStorage
      custodianOne: null,
      custodianTwo: null,
    };
  },
  computed: {
    allThemes() {
      return { ...this.themes, ...this.customThemes };
    },
    themeStyles() {
      const theme = this.allThemes[this.currentTheme];
      if (!theme) return {};
      
      const t = theme.colors;
      return {
        '--main-font': theme.font,
        '--main-bg': t.mainBg,
        '--text-color': t.textColor,
        '--editable-text-color': t.editableTextColor,
        '--custody-jeff-bg': t.jeff,
        '--custody-deanna-bg': t.deanna,
        '--today-border': t.todayBorder,
        '--other-month-bg': t.otherMonthBg,
        '--other-month-color': t.otherMonthColor,
        '--grid-lines': t.gridLines,
        '--header-bg': t.headerBg,
        '--footer-bg': t.footerBg,
        '--icon-color': t.iconColor,
        '--icon-active': t.iconActive,
      };
    },
    todayIsoDate() {
      return this.dateToIso(new Date());
    },
    custodyStreak() {
      const now = new Date();

      const getSwitchoverTime = (date) => {
        const dayOfWeek = date.getDay(); // 0=Sun, 6=Sat
        const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
        const dateIso = this.dateToIso(date);
        const dayEvents = this.events[dateIso] || [];
        const hasDaycare = dayEvents.some(e => e && e.content && e.content.toLowerCase().includes('daycare'));
        // 5pm for weekdays, 12pm (noon) for weekends/daycare days
        return isWeekend || hasDaycare ? 12 : 17;
      };

      const getEffectiveOwnerForDate = (refDate) => {
        const date = new Date(refDate);
        const ownerOnRefDay = this.getCustodyInfo(this.dateToIso(date)).owner;
        
        const prevDay = new Date(date);
        prevDay.setDate(date.getDate() - 1);
        const ownerOnPrevDay = this.getCustodyInfo(this.dateToIso(prevDay)).owner;
        
        if (ownerOnRefDay !== ownerOnPrevDay) {
          const switchHour = getSwitchoverTime(date);
          if (date.getHours() < switchHour) {
            return ownerOnPrevDay;
          }
        }
        return ownerOnRefDay;
      };

      const currentEffectiveOwner = getEffectiveOwnerForDate(now);

      let streak = 0;
      let dateToCheck = new Date(now);
      // Always start counting from the day before the current one.
      dateToCheck.setDate(dateToCheck.getDate() - 1);
      
      for (let i = 0; i < 365; i++) {
        const endOfDay = new Date(dateToCheck);
        endOfDay.setHours(23, 59, 59);

        if (getEffectiveOwnerForDate(endOfDay) === currentEffectiveOwner) {
          streak++;
          dateToCheck.setDate(dateToCheck.getDate() - 1);
        } else {
          break;
        }
      }

      return streak;
    },
    currentYear() {
      return this.currentDate.getFullYear();
    },
    currentMonth() {
      return this.currentDate.getMonth();
    },
    currentMonthName() {
      return this.currentDate.toLocaleString('default', { month: 'long' });
    },
    calendarDays() {
      try {
        const year = this.currentYear;
        const month = this.currentMonth;
        const firstDayOfMonth = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();

        let days = [];
        for (let i = 0; i < firstDayOfMonth; i++) {
          const prevMonthDate = new Date(year, month, 0);
          const day = prevMonthDate.getDate() - i;
          const date = new Date(year, month - 1, day);
          days.unshift({ date: this.dateToIso(date), day: day, isCurrentMonth: false });
        }

        for (let i = 1; i <= daysInMonth; i++) {
          const date = new Date(year, month, i);
          days.push({ date: this.dateToIso(date), day: i, isCurrentMonth: true });
        }

        const lastDayOfMonth = new Date(year, month, daysInMonth).getDay();
        const remainingDays = 6 - lastDayOfMonth;
        for (let i = 1; i <= remainingDays; i++) {
          const date = new Date(year, month + 1, i);
          days.push({ date: this.dateToIso(date), day: i, isCurrentMonth: false });
        }
        
        // Ensure we always have 6 weeks (42 days)
        while (days.length < 42) {
            const lastDate = new Date(days[days.length-1].date + 'T00:00:00');
            const nextDate = new Date(lastDate.setDate(lastDate.getDate() + 1));
            days.push({ date: this.dateToIso(nextDate), day: nextDate.getDate(), isCurrentMonth: false });
        }

        return days;
      } catch (error) {
        console.error('Error generating calendar days:', error);
        return [];
      }
    },
    custodyShare() {
      const currentMonthDays = this.calendarDays.filter(day => day.isCurrentMonth);
      const totalDays = currentMonthDays.length;
      if (totalDays === 0) {
        return { jeff: 0, deanna: 0 };
      }

      let jeffDays = 0;
      for (const day of currentMonthDays) {
        const custodyInfo = this.getCustodyInfo(day.date);
        if (custodyInfo.owner === 'jeff') {
          jeffDays++;
        }
      }

      const jeffPercentage = Math.round((jeffDays / totalDays) * 100);
      const deannaPercentage = 100 - jeffPercentage;
      
      return { jeff: jeffPercentage, deanna: deannaPercentage };
    },
  },
  methods: {
    deleteCustomTheme(themeName) {
      if (!this.customThemes[themeName]) return;

      if (this.currentTheme === themeName) {
        this.setTheme('Stork');
      }

      const newCustomThemes = { ...this.customThemes };
      delete newCustomThemes[themeName];
      this.customThemes = newCustomThemes;

      localStorage.setItem('customCalendarThemes', JSON.stringify(this.customThemes));
    },
    loadCustomThemes() {
      const savedThemes = localStorage.getItem('customCalendarThemes');
      if (savedThemes) {
        this.customThemes = JSON.parse(savedThemes);
      }
    },
    saveCustomTheme(themeData) {
      const newThemeName = themeData.name;
      // Using Vue.set or this.$set is not needed in Vue 3. Direct assignment is reactive.
      this.customThemes[newThemeName] = {
        font: themeData.font,
        colors: themeData.colors,
      };
      // Create a new object to ensure reactivity when merging
      this.customThemes = { ...this.customThemes }; 
      localStorage.setItem('customCalendarThemes', JSON.stringify(this.customThemes));
      
      // Automatically switch to the new theme
      this.setTheme(newThemeName);
    },
    setTheme(themeName) {
      this.currentTheme = themeName;
      localStorage.setItem('calendarTheme', themeName);
    },
    toggleIconLabels() {
      this.showIconLabels = !this.showIconLabels;
      localStorage.setItem('showIconLabels', this.showIconLabels);
    },
    toggleSettingsModal() {
      this.showSettingsModal = !this.showSettingsModal;
    },
    dateToIso(d) {
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    },
    setEventRef(el, date, position) {
      if (el) {
        this.eventRefs[`${date}-${position}`] = el;
      }
    },
    getEventContent(date, position) {
      if (this.events[date] && this.events[date][position]) {
        return this.events[date][position].content || '';
      }
      return '';
    },
    getSchoolEvent(date) {
      return this.schoolEvents[date] || null;
    },
    getTemperature(date) {
      if (!this.weather[date] || this.weather[date].temp === undefined) return null;
      return Math.round(this.weather[date].temp);
    },
    getCloudCover(date) {
        if (!this.weather[date] || !this.weather[date].cloudcover === undefined) return 0;
        return this.weather[date].cloudcover;
    },
    getPrecipitationChance(date) {
      if (!this.weather[date] || this.weather[date].precip === undefined) return 0;
      return this.weather[date].precip;
    },
    getWaveInfo(date) {
        const height = this.waves[date];
        if (height === undefined || height === null) return { count: 0, text: '' };

        if (height < 1) { // Low waves (< 1m)
            return { count: 1, text: `${height.toFixed(1)}m` };
        } else if (height >= 1 && height < 2) { // Medium waves (1-2m)
            return { count: 2, text: `${height.toFixed(1)}m` };
        } else { // High waves (>= 2m)
            return { count: 3, text: `${height.toFixed(1)}m` };
        }
    },
    toggleRaindrops() {
      this.showRaindrops = !this.showRaindrops;
      localStorage.setItem('showRaindrops', this.showRaindrops);
    },
    toggleWaves() {
      this.showWaves = !this.showWaves;
      localStorage.setItem('showWaves', this.showWaves);
    },
    toggleSchoolEvents() {
        this.showSchoolEvents = !this.showSchoolEvents;
        localStorage.setItem('showSchoolEvents', this.showSchoolEvents);
        if (this.showSchoolEvents && Object.keys(this.schoolEvents).length === 0) {
            this.fetchSchoolEvents();
        }
    },
    async fetchCustodianInfo() {
      try {
        const response = await axios.get('/api/family/custodians');
        this.custodianOne = response.data.custodian_one;
        this.custodianTwo = response.data.custodian_two;
        console.log("Calendar.vue: Fetched custodian info", this.custodianOne, this.custodianTwo);
      } catch (error) {
        console.error('Error fetching custodian info:', error);
        // Fallback to hardcoded values
        this.custodianOne = { id: 'jeff-id', first_name: 'Jeff' };
        this.custodianTwo = { id: 'deanna-id', first_name: 'Deanna' };
      }
    },
    getCustodyInfo(date) {
      const event = (this.events[date] && this.events[date][4]) ? this.events[date][4].content : null;
      // Adding 'T00:00:00' avoids timezone issues when getting the day
      const dayOfWeek = new Date(date + 'T00:00:00').getUTCDay();

      let owner;

      if (event === 'jeff' || event === 'deanna') {
        owner = event;
      } else {
        // Default logic: 0=Sun, 1=Mon, 6=Sat
        owner = [0, 1, 6].includes(dayOfWeek) ? 'jeff' : 'deanna';
      }

      if (owner === 'jeff') {
        const ownerName = this.custodianOne ? this.custodianOne.first_name : 'Jeff';
        const ownerId = this.custodianOne ? this.custodianOne.id : null;
        return { owner: 'jeff', text: ownerName, class: 'custody-jeff', id: ownerId };
      } else {
        const ownerName = this.custodianTwo ? this.custodianTwo.first_name : 'Deanna';
        const ownerId = this.custodianTwo ? this.custodianTwo.id : null;
        return { owner: 'deanna', text: ownerName, class: 'custody-deanna', id: ownerId };
      }
    },
    async toggleCustody(date) {
      console.log('toggleCustody called with date:', date);
      console.log('custodianOne:', this.custodianOne);
      console.log('custodianTwo:', this.custodianTwo);
      
      const currentInfo = this.getCustodyInfo(date);
      const newOwner = currentInfo.owner === 'jeff' ? 'deanna' : 'jeff';
      
      // Get the custodian ID for the new owner
      let newCustodianId;
      if (newOwner === 'jeff') {
        newCustodianId = this.custodianOne ? this.custodianOne.id : null;
      } else {
        newCustodianId = this.custodianTwo ? this.custodianTwo.id : null;
      }

      if (!newCustodianId) {
        console.error('Error: No custodian ID available for', newOwner);
        return;
      }

      console.log('Sending custody request to NEW CUSTODY API:', { date, custodian_id: newCustodianId });

      try {
        const response = await axios.post('/api/custody', {
          date: date,
          custodian_id: newCustodianId,
        });
        
        // Update local events storage to reflect the change
        const updatedEvents = { ...this.events };
        if (!updatedEvents[date]) {
          updatedEvents[date] = [];
        }
        // Store the response directly since it's already in the right format
        updatedEvents[date][4] = response.data;
        this.events = updatedEvents;

        console.log("Calendar.vue: Custody saved successfully via new custody API");
      } catch (error) {
        console.error('Error saving custody event:', error);
        alert('Failed to update custody. Please try again.');
      }
    },
    async fetchWeather() {
      if (this.calendarDays.length === 0) {
        return;
      }
      const startDate = this.calendarDays[0].date;
      const endDate = this.calendarDays[this.calendarDays.length - 1].date;

      console.log(`Calendar.vue: fetchWeather() called for ${startDate} to ${endDate}`);
      try {
        const response = await axios.get(`/api/weather/34.29/-77.97?start_date=${startDate}&end_date=${endDate}`);
        const weatherData = response.data;
        const newWeather = {};
        if (weatherData.daily) {
          weatherData.daily.time.forEach((date, index) => {
            newWeather[date] = {
                precip: weatherData.daily.precipitation_probability_mean[index],
                cloudcover: weatherData.daily.cloudcover_mean[index],
                temp: weatherData.daily.temperature_2m_max[index],
            };
          });
        }
        this.weather = newWeather;
        console.log("Calendar.vue: Weather data fetched successfully", this.weather);
      } catch (error) {
        console.error('Error fetching weather data:', error);
      }
    },
    async fetchEvents() {
      console.log("Calendar.vue: fetchEvents() called");
      try {
        // Fetch regular events (if any exist)
        const eventsResponse = await axios.get(`/api/events/${this.currentYear}/${this.currentMonth + 1}`);
        this.events = {};
        eventsResponse.data.forEach(event => {
          if (!this.events[event.event_date]) {
            this.events[event.event_date] = [];
          }
          this.events[event.event_date][event.position] = event;
        });
        
        // Fetch custody data from the new custody API
        const custodyResponse = await axios.get(`/api/custody/${this.currentYear}/${this.currentMonth + 1}`);
        custodyResponse.data.forEach(custodyEvent => {
          if (!this.events[custodyEvent.event_date]) {
            this.events[custodyEvent.event_date] = [];
          }
          // Store custody as position 4 for frontend compatibility
          this.events[custodyEvent.event_date][4] = custodyEvent;
        });
        
        console.log("Calendar.vue: Events and custody fetched successfully", this.events);
        this.adjustFontSize();
      } catch (error) {
        console.error('Error fetching events/custody:', error);
        // Don't break the app if API fails
      }
    },
    async fetchSchoolEvents() {
        console.log("Calendar.vue: fetchSchoolEvents() called");
        try {
            const response = await axios.get('/api/school-events');
            this.schoolEvents = response.data;
            console.log("Calendar.vue: School events fetched successfully", this.schoolEvents);
            this.adjustFontSize();
        } catch (error) {
            console.error('Error fetching school events:', error);
        }
    },
    async fetchWaves() {
        if (this.calendarDays.length === 0) {
            return;
        }
        const startDate = this.calendarDays[0].date;
        const endDate = this.calendarDays[this.calendarDays.length - 1].date;

        console.log(`Calendar.vue: fetchWaves() called for ${startDate} to ${endDate}`);
        try {
            // Coords for Wrightsville Beach, NC
            const response = await axios.get(`/api/waves/34.21/-77.80?start_date=${startDate}&end_date=${endDate}`);
            const waveData = response.data;
            const newWaves = {};
            if (waveData.daily) {
                waveData.daily.time.forEach((date, index) => {
                    newWaves[date] = waveData.daily.wave_height_max[index];
                });
            }
            this.waves = newWaves;
            console.log("Calendar.vue: Wave data fetched successfully", this.waves);
        } catch (error) {
            console.error('Error fetching wave data:', error);
        }
    },
    async saveEvent(event, date, position) {
      console.log('saveEvent called with:', { date, position });
      
      // Custody events (position 4) should use toggleCustody instead
      if (position === 4) {
        console.log('Position 4 detected - redirecting to toggleCustody instead of saveEvent');
        return; // Don't handle custody events here
      }
      
      const content = event.target.innerText;
      console.log('content:', content);
      
      if (this.events[date] && this.events[date][position] && this.events[date][position].content === content) {
          return;
      }
      
      console.log('Sending old format event request:', { event_date: date, content, position });
      
      try {
        const response = await axios.post('/api/events', {
          event_date: date,
          content: content,
          position: position,
        });

        const updatedEvents = { ...this.events };
        if (!updatedEvents[date]) {
          updatedEvents[date] = [];
        }
        updatedEvents[date][position] = response.data;
        this.events = updatedEvents;

        console.log("Calendar.vue: Event saved successfully");
      } catch (error) {
        console.error('Error saving event:', error);
      }
    },
    prevMonth() {
      console.log("Calendar.vue: prevMonth() called");
      this.currentDate = new Date(this.currentYear, this.currentMonth - 1, 1);
      this.fetchEvents();
    },
    nextMonth() {
      console.log("Calendar.vue: nextMonth() called");
      this.currentDate = new Date(this.currentYear, this.currentMonth + 1, 1);
      this.fetchEvents();
    },
    handleFocus(el) {
      // On focus, reset to a standard style that allows scrolling.
      el.style.fontSize = '12px';
      el.style.textOverflow = 'clip';
      el.style.overflowX = 'auto';
    },
    handleBlur(event, date, position) {
      const el = event.target;
      // On blur, reset styles for display and save the event.
      el.style.overflowX = 'hidden';
      el.scrollLeft = 0; // Reset scroll
      this.adjustFontSize(); // Rerun sizing for all elements to ensure consistency
      this.saveEvent(event, date, position);
    },
    calculateRequiredFontSize(el, sizeFactor = 0.7) {
        const MIN_FONT_SIZE = 9;
        const placeholderHeight = el.clientHeight;

        if (placeholderHeight <= 0) return MIN_FONT_SIZE;

        // Set a base font size relative to the row height to measure against
        const baseFontSize = placeholderHeight * sizeFactor;
        el.style.fontSize = `${baseFontSize}px`;
        
        const parentWidth = el.clientWidth;
        const textWidth = el.scrollWidth;
        
        let newFontSize = baseFontSize;
        if (textWidth > parentWidth) {
            newFontSize = baseFontSize * (parentWidth / textWidth);
        }

        // Return the calculated size, but not smaller than the minimum
        return Math.max(newFontSize, MIN_FONT_SIZE);
    },
    adjustElementFontSize(el) {
      // This function is for single, non-uniform event placeholders.
      const CHAR_LIMIT_FOR_ELLIPSIS = 32;

      if (el.innerText.length < CHAR_LIMIT_FOR_ELLIPSIS) {
        el.style.textOverflow = 'clip';
      } else {
        el.style.textOverflow = 'ellipsis';
      }
      
      const newFontSize = this.calculateRequiredFontSize(el);
      el.style.fontSize = `${newFontSize}px`;
    },
    adjustFontSize() {
      this.$nextTick(() => {
        if (!this.$el) return;

        // Adjust regular event placeholders individually
        const eventPlaceholders = this.$el.querySelectorAll('.event-placeholder:not(.custody-row)');
        eventPlaceholders.forEach(el => {
          this.adjustElementFontSize(el);
        });

        // Adjust custody rows to have a uniform font size
        const custodyRows = this.$el.querySelectorAll('.custody-row');
        if (custodyRows.length > 0) {
            let minFontSize = Infinity;
            
            // Calculate minimum required font size across all custody rows
            custodyRows.forEach(el => {
                const requiredSize = this.calculateRequiredFontSize(el, 0.6);
                if (requiredSize < minFontSize) {
                    minFontSize = requiredSize;
                }
            });

            // Apply the smallest font size to all custody rows
            custodyRows.forEach(el => {
                el.style.fontSize = `${minFontSize}px`;
            });
        }
      });
    },
    async sendSummary() {
      try {
        const response = await axios.post('/api/summary/email');
        if (response.data.status === 'email_sent_successfully') {
          alert(`Email summary successfully sent to jeff@levensailor.com!`);
        } else {
          alert(`Failed to send email: ${response.data.details || response.data.error}`);
        }
      } catch (error) {
        console.error('Error sending summary:', error);
        alert('Failed to send summary. Check the console for details.');
      }
    },
  },
  watch: {
    currentDate: {
      handler() {
        console.log("Calendar.vue: currentDate changed, fetching events");
        this.fetchEvents();
        this.fetchWaves();
        // School events are for the whole year, no need to refetch on month change
      },
      immediate: false
    }
  },
  mounted() {
    console.log("Calendar.vue: mounted() called");
    window.addEventListener('resize', this.adjustFontSize);
    this.$nextTick(() => {
      this.loadCustomThemes(); // Load custom themes first
      this.currentTheme = localStorage.getItem('calendarTheme') || 'Stork';
      this.fetchCustodianInfo(); // Fetch custodian info before other data
      this.fetchEvents();
      this.fetchWeather();
      this.fetchWaves();
      if (this.showSchoolEvents) {
        this.fetchSchoolEvents();
      }
    });
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.adjustFontSize);
  },
};
</script>

<style scoped>
.calendar-container {
  height: 100%;
  position: relative;
}

.calendar {
  display: flex;
  flex-direction: column;
  height: 100%;
  font-family: var(--main-font);
  background-color: var(--main-bg);
  color: var(--text-color);
}

.calendar-header {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  padding: 10px 0;
  background-color: var(--header-bg);
  text-align: center;
  font-weight: bold;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  grid-auto-rows: 1fr;
  flex-grow: 1;
  gap: 1px;
  background-color: var(--grid-lines);
  border: 1px solid var(--grid-lines);
  overflow-y: auto;
}

.day-cell {
  background-color: var(--main-bg);
  display: flex;
  flex-direction: column;
  position: relative;
  overflow: hidden;
  padding: 4px;
  min-height: 90px;
}

.day-cell.is-today {
  border: 2px solid var(--today-border);
}

.day-cell.other-month {
  background-color: var(--other-month-bg);
  color: var(--other-month-color);
}

.day-header-icons {
  position: absolute;
  top: 2px;
  left: 2px;
  display: flex;
  gap: 4px;
  font-size: 10px;
  align-items: center;
}

.flight-info, .wave-info, .school-event-info, .temp-info {
  display: flex;
  align-items: center;
  gap: 2px;
  background-color: rgba(255, 255, 255, 0.7);
  padding: 1px 3px;
  border-radius: 3px;
  color: #333;
}

.day-number {
  position: absolute;
  top: 2px;
  right: 5px;
  font-size: 14px;
  font-weight: bold;
}

.events {
  flex-grow: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-around;
  padding-top: 1.5em;
  position: relative;
  z-index: 2;
  height: calc(100% - 20px);
  overflow: hidden;
}

.event-placeholder {
  flex-grow: 1;
  border-bottom: 1px solid #eee;
  padding: 1px 2px;
  white-space: nowrap;
  overflow: hidden;
  color: var(--editable-text-color);
}

.custody-row {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 0.4em;
  font-weight: 500;
  color: var(--text-color);
  cursor: pointer;
  -webkit-user-select: none;
  -ms-user-select: none;
  user-select: none;
  font-size: 12px;
  padding-left: 5px;
}

.child-icon {
  width: 1.2em;
  height: 1.2em;
  flex-shrink: 0;
}

.custody-jeff {
  background-color: var(--custody-jeff-bg);
}

.custody-deanna {
  background-color: var(--custody-deanna-bg);
}

.event-placeholder:empty::before {
    content: " ";
    white-space: pre;
}

.calendar-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background-color: var(--footer-bg);
  font-size: 14px;
}

.footer-icons, .footer-actions {
  display: flex;
  gap: 10px;
  position: relative;
}

.month-nav {
  display: flex;
  align-items: center;
  gap: 15px;
}

.icon-button {
  background: none;
  border: none;
  cursor: pointer;
  padding: 5px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.icon-button svg {
  width: 20px;
  height: 20px;
  stroke: var(--icon-color);
}

.icon-button svg.active {
  stroke: var(--icon-active);
  fill: var(--icon-active);
  fill-opacity: 0.1;
}

.custody-share {
  font-size: 12px;
  color: #666;
  margin-left: 20px;
}

.school-event-icon {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
  fill: currentColor;
}

.icon-label {
  font-size: 10px;
  color: var(--icon-color);
}

/* ====== MOBILE OPTIMIZATIONS ====== */
@media (max-width: 768px) {
  .calendar {
    /* Add safe area padding for iPhone notch/dynamic island - only top */
    padding-top: env(safe-area-inset-top);
    padding-left: env(safe-area-inset-left);
    padding-right: env(safe-area-inset-right);
    /* Remove bottom padding to eliminate white space */
    /* padding-bottom: env(safe-area-inset-bottom); */
  }

  .calendar-header {
    padding: 8px 0;
    font-size: 14px;
    /* Ensure header is below the notch/dynamic island */
    margin-top: 10px;
  }

  .day-cell {
    min-height: 80px;
    padding: 2px;
  }

  .day-number {
    font-size: 12px;
    top: 1px;
    right: 3px;
  }

  .day-header-icons {
    top: 1px;
    left: 1px;
    gap: 2px;
    font-size: 8px;
  }

  .flight-info, .wave-info, .school-event-info, .temp-info {
    padding: 1px 2px;
    font-size: 8px;
  }

  .events {
    padding-top: 1em;
  }

  .event-placeholder {
    font-size: 10px;
    padding: 1px;
  }

  .custody-row {
    font-size: 10px;
    gap: 0.2em;
    padding-left: 3px;
  }

  .child-icon {
    width: 1em;
    height: 1em;
  }

  .calendar-footer {
    padding: 4px 8px; /* Reduced from 8px to 4px */
    font-size: 12px;
    flex-wrap: wrap;
    gap: 4px; /* Reduced from 8px to 4px */
    min-height: 60px; /* Set a smaller fixed height */
    /* Extend footer to bottom edge to eliminate grey bar */
    padding-bottom: calc(4px + env(safe-area-inset-bottom));
    margin-bottom: calc(-1 * env(safe-area-inset-bottom));
  }

  .footer-icons, .footer-actions {
    gap: 6px; /* Reduced from 8px to 6px */
  }

  .month-nav {
    gap: 8px; /* Reduced from 10px to 8px */
    order: -1;
    width: 100%;
    justify-content: center;
  }

  .icon-button {
    padding: 4px; /* Reduced from 8px to 4px */
    min-width: 36px; /* Reduced from 44px to 36px */
    min-height: 36px; /* Reduced from 44px to 36px */
  }

  .icon-button svg {
    width: 16px; /* Reduced from 18px to 16px */
    height: 16px; /* Reduced from 18px to 16px */
  }

  .icon-label {
    font-size: 8px; /* Reduced from 9px to 8px */
  }

  .custody-share {
    font-size: 9px; /* Reduced from 10px to 9px */
    margin-left: 8px; /* Reduced from 10px to 8px */
    text-align: center;
    width: 100%;
  }
}

/* Ultra-small devices (phones in portrait) */
@media (max-width: 480px) {
  .calendar-header {
    font-size: 12px;
    padding: 6px 0;
    margin-top: 8px; /* Slightly less margin for smaller screens */
  }

  .day-cell {
    min-height: 70px;
    padding: 1px;
  }

  .day-number {
    font-size: 11px;
  }

  .day-header-icons {
    font-size: 7px;
    gap: 1px;
  }

  .flight-info, .wave-info, .school-event-info, .temp-info {
    font-size: 7px;
    padding: 0px 1px;
  }

  .event-placeholder {
    font-size: 9px;
  }

  .custody-row {
    font-size: 9px;
  }

  .calendar-footer {
    padding: 3px 6px; /* Further reduced padding */
    font-size: 11px;
    min-height: 50px; /* Even smaller height for small screens */
    /* Extend footer to bottom edge */
    padding-bottom: calc(3px + env(safe-area-inset-bottom));
    margin-bottom: calc(-1 * env(safe-area-inset-bottom));
  }

  .icon-button {
    padding: 3px; /* Further reduced padding */
    min-width: 32px; /* Smaller touch targets */
    min-height: 32px;
  }

  .icon-button svg {
    width: 14px; /* Smaller icons */
    height: 14px;
  }

  .custody-share {
    font-size: 8px; /* Smaller text */
    margin-left: 0;
  }

  /* Hide icon labels on very small screens */
  .icon-label {
    display: none;
  }

  /* Stack footer items more compactly */
  .footer-icons, .footer-actions {
    gap: 4px; /* Reduced gap */
  }

  .month-nav {
    gap: 6px; /* Reduced gap */
  }
}

/* Landscape orientation optimizations */
@media (max-width: 768px) and (orientation: landscape) {
  .calendar-header {
    margin-top: 5px; /* Less margin in landscape */
  }

  .day-cell {
    min-height: 60px;
  }

  .calendar-footer {
    padding: 2px 6px; /* Very compact in landscape */
    min-height: 40px; /* Minimal height in landscape */
    /* Extend footer to bottom edge */
    padding-bottom: calc(2px + env(safe-area-inset-bottom));
    margin-bottom: calc(-1 * env(safe-area-inset-bottom));
  }

  .icon-button {
    padding: 2px;
    min-width: 30px;
    min-height: 30px;
  }

  .icon-button svg {
    width: 12px;
    height: 12px;
  }

  .month-nav {
    flex-direction: row;
    width: auto;
  }

  .custody-share {
    width: auto;
    margin-left: 8px;
    font-size: 8px;
  }
}

/* Touch-friendly improvements */
@media (pointer: coarse) {
  .event-placeholder {
    min-height: 20px;
    touch-action: manipulation;
  }

  .custody-row {
    min-height: 24px;
    touch-action: manipulation;
  }

  .icon-button {
    touch-action: manipulation;
  }
}
</style>
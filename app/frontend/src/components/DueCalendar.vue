<template>
  <div class="calendar">
    <div class="calendar-head">
      <button type="button" class="calendar-step" aria-label="Mes anterior" @click="step(-1)">‹</button>
      <div class="calendar-title">
        <strong>{{ year }}</strong>
        <span>{{ monthName }}</span>
      </div>
      <button type="button" class="calendar-step" aria-label="Mes siguiente" @click="step(1)">›</button>
    </div>
    <div class="calendar-grid">
      <span v-for="name in weekdays" :key="name" class="calendar-weekday">{{ name }}</span>
      <span v-for="blank in leadingBlanks" :key="'blank' + blank"></span>
      <button
        v-for="day in days"
        :key="day.iso"
        type="button"
        class="calendar-day"
        :class="{ 'is-today': day.isToday, 'is-marked': day.isMarked, 'is-selected': day.iso === selected }"
        @click="$emit('select', day.iso)"
      >{{ day.number }}</button>
    </div>
  </div>
</template>

<script>
import { toIsoDate, today } from '@/obligations'

const MONTH_NAMES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto',
  'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']

export default {
  name: 'due-calendar',
  props: ['marked', 'selected'],
  data () {
    const now = today()
    return {
      year: now.getFullYear(),
      month: now.getMonth(),
      weekdays: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
    }
  },
  computed: {
    monthName () {
      return MONTH_NAMES[this.month]
    },
    // Weeks start on Monday, so Sunday moves to the end.
    leadingBlanks () {
      const first = new Date(this.year, this.month, 1).getDay()
      return (first + 6) % 7
    },
    days () {
      const count = new Date(this.year, this.month + 1, 0).getDate()
      const todayIso = toIsoDate(today())
      const days = []
      for (let number = 1; number <= count; number++) {
        const iso = toIsoDate(new Date(this.year, this.month, number))
        days.push({
          number: number,
          iso: iso,
          isToday: iso === todayIso,
          isMarked: this.marked.indexOf(iso) !== -1
        })
      }
      return days
    }
  },
  methods: {
    step (delta) {
      const date = new Date(this.year, this.month + delta, 1)
      this.year = date.getFullYear()
      this.month = date.getMonth()
    }
  }
}
</script>

<style scoped>
.calendar-head {
  align-items: center;
  display: flex;
  justify-content: center;
  gap: 1.5rem;
  margin-bottom: 1.2rem;
}

.calendar-title {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
  text-align: center;
}

.calendar-title strong {
  font-size: 1.3rem;
}

.calendar-step {
  background: transparent;
  border: none;
  color: var(--pf-text);
  cursor: pointer;
  font-size: 1.8rem;
  line-height: 1;
}

.calendar-grid {
  display: grid;
  gap: 0.45rem;
  grid-template-columns: repeat(7, 1fr);
  justify-items: center;
}

.calendar-weekday {
  color: var(--pf-muted);
  font-weight: 700;
  margin-bottom: 0.3rem;
}

.calendar-day {
  background: transparent;
  border: none;
  border-radius: 50%;
  color: var(--pf-text);
  cursor: pointer;
  height: 2.3rem;
  width: 2.3rem;
}

.calendar-day:hover {
  background: var(--pf-card);
}

.calendar-day.is-marked {
  background: var(--pf-line);
  font-weight: 700;
}

.calendar-day.is-today {
  box-shadow: inset 0 0 0 2px var(--pf-accent);
}

.calendar-day.is-selected {
  background: var(--pf-accent);
  color: var(--pf-accent-text);
}
</style>

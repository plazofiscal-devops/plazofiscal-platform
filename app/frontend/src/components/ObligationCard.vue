<template>
  <li class="card" :class="'card-' + state.tone">
    <button
      class="card-done"
      type="button"
      title="Marcar como presentada"
      aria-label="Marcar como presentada"
      @click="$emit('present')"
    ></button>
    <div class="card-body">
      <div class="card-date">{{ dueDate }}</div>
      <div class="card-client">{{ obligation.client || obligation.content }}</div>
      <div class="card-detail">
        <span class="card-tax">{{ tax }}</span>
        <span v-if="obligation.note" class="card-note">{{ obligation.note }}</span>
      </div>
    </div>
    <span class="card-chip" :class="'chip-' + state.tone">{{ state.text }}</span>
  </li>
</template>

<script>
import { dueState, formatDate, taxLabel } from '@/obligations'

export default {
  name: 'obligation-card',
  props: ['obligation'],
  computed: {
    state () {
      return dueState(this.obligation.dueDate)
    },
    dueDate () {
      return this.obligation.dueDate ? formatDate(this.obligation.dueDate) : 'Sin fecha'
    },
    tax () {
      return taxLabel(this.obligation.tax)
    }
  }
}
</script>

<style scoped>
.card {
  align-items: center;
  background: var(--pf-card);
  border-left: 4px solid transparent;
  border-radius: 10px;
  display: flex;
  gap: 1rem;
  list-style: none;
  margin-bottom: 0.9rem;
  padding: 1rem 1.2rem;
}

.card:hover {
  background: var(--pf-card-hover);
}

.card-overdue {
  border-left-color: var(--pf-danger);
}

.card-soon {
  border-left-color: var(--pf-accent);
}

.card-done {
  background: transparent;
  border: 2px solid var(--pf-muted);
  border-radius: 50%;
  cursor: pointer;
  flex-shrink: 0;
  height: 1.6rem;
  width: 1.6rem;
}

.card-done:hover {
  background: var(--pf-accent);
  border-color: var(--pf-accent);
}

.card-body {
  flex-grow: 1;
  min-width: 0;
}

.card-date {
  color: var(--pf-muted);
  font-size: 0.85rem;
}

.card-client {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0.15rem 0;
}

.card-detail {
  color: var(--pf-muted);
  font-size: 0.9rem;
}

.card-note::before {
  content: '·';
  margin: 0 0.4rem;
}

.card-chip {
  border-radius: 999px;
  flex-shrink: 0;
  font-size: 0.85rem;
  padding: 0.3rem 0.8rem;
}

.chip-overdue {
  background: var(--pf-danger);
  color: #ffffff;
}

.chip-soon {
  background: var(--pf-accent);
  color: var(--pf-accent-text);
}

.chip-quiet {
  background: var(--pf-line);
  color: var(--pf-muted);
}
</style>

<template>
  <li class="obligation" :class="'obligation-' + state.tone">
    <button
      class="obligation-done"
      type="button"
      title="Marcar como presentada"
      aria-label="Marcar como presentada"
      @click="$emit('present')"
    ></button>
    <div class="obligation-body">
      <div class="obligation-date">{{ dueDate }}</div>
      <div class="obligation-client">{{ obligation.client || obligation.content }}</div>
      <div class="obligation-detail">
        <span class="obligation-tax">{{ tax }}</span>
        <span v-if="obligation.note" class="obligation-note">{{ obligation.note }}</span>
      </div>
    </div>
    <span class="obligation-chip" :class="'chip-' + state.tone">{{ state.text }}</span>
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
.obligation {
  align-items: center;
  background: var(--pf-card);
  border-radius: 10px;
  display: flex;
  gap: 1rem;
  list-style: none;
  margin-bottom: 0.9rem;
  padding: 1rem 1.2rem;
}

.obligation:hover {
  background: var(--pf-card-hover);
}

.obligation-done {
  background: transparent;
  border: 2px solid var(--pf-muted);
  border-radius: 50%;
  cursor: pointer;
  flex-shrink: 0;
  height: 1.6rem;
  width: 1.6rem;
}

.obligation-overdue .obligation-done {
  border-color: var(--pf-danger);
}

.obligation-soon .obligation-done {
  border-color: var(--pf-accent);
}

.obligation-done:hover {
  background: var(--pf-accent);
  border-color: var(--pf-accent);
}

.obligation-body {
  flex-grow: 1;
  min-width: 0;
}

.obligation-date {
  color: var(--pf-muted);
  font-size: 0.85rem;
}

.obligation-client {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0.15rem 0;
}

.obligation-detail {
  color: var(--pf-muted);
  font-size: 0.9rem;
}

.obligation-note::before {
  content: '·';
  margin: 0 0.4rem;
}

.obligation-chip {
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

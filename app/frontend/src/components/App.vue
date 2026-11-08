<template>
  <div id="app">
    <router-view></router-view>
  </div>
</template>

<script>
export default {
  name: 'app'
}
</script>

<style>
:root {
  --pf-background: #121212;
  --pf-panel: #1b1b1b;
  --pf-card: #262626;
  --pf-card-hover: #2e2e2e;
  --pf-line: #333333;
  --pf-text: #f0f0f0;
  --pf-muted: #9a9a9a;
  --pf-accent: #f2c14e;
  --pf-accent-text: #1b1b1b;
  --pf-danger: #e05d5d;
}

html,
body {
  background: var(--pf-background);
  color: var(--pf-text);
  min-height: 100%;
}

#app {
  font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: var(--pf-text);
}

.pf-input {
  background: var(--pf-card);
  border: 1px solid var(--pf-line);
  border-radius: 8px;
  color: var(--pf-text);
  padding: 0.7rem 0.9rem;
  width: 100%;
}

.pf-input:focus {
  border-color: var(--pf-accent);
  outline: none;
}

.pf-input::placeholder {
  color: var(--pf-muted);
}

.pf-button {
  background: var(--pf-accent);
  border: none;
  border-radius: 8px;
  color: var(--pf-accent-text);
  cursor: pointer;
  font-weight: 600;
  padding: 0.7rem 1.2rem;
}

.pf-button:hover {
  filter: brightness(1.08);
}

.pf-button-quiet {
  background: var(--pf-card);
  color: var(--pf-text);
}

.pf-error {
  color: var(--pf-danger);
  min-height: 1.5rem;
}
</style>

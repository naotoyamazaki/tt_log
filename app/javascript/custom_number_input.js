document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.number-input .plus').forEach(button => {
    button.addEventListener('click', (event) => {
      const input = event.target.parentNode.querySelector('input[type=number]');
      input.stepUp();
      event.preventDefault();
    });
  });

  document.querySelectorAll('.number-input .minus').forEach(button => {
    button.addEventListener('click', (event) => {
      const input = event.target.parentNode.querySelector('input[type=number]');
      input.stepDown();
      event.preventDefault();
    });
  });
});

/**
 * Validador de CPF brasileiro.
 * Porta direta do CpfValidator.java (domain/validation).
 */

export function clean(cpf) {
  if (!cpf) return null;
  return cpf.replace(/\D/g, '');
}

export function isValid(cpf) {
  if (!cpf) return false;

  cpf = clean(cpf);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;

  let sum = 0;
  for (let i = 0; i < 9; i++) sum += parseInt(cpf[i]) * (10 - i);
  let d1 = 11 - (sum % 11);
  if (d1 >= 10) d1 = 0;
  if (parseInt(cpf[9]) !== d1) return false;

  sum = 0;
  for (let i = 0; i < 10; i++) sum += parseInt(cpf[i]) * (11 - i);
  let d2 = 11 - (sum % 11);
  if (d2 >= 10) d2 = 0;

  return parseInt(cpf[10]) === d2;
}

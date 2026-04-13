import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isValid, clean } from './cpf-validator.mjs';

describe('CPF Validator', () => {
  it('valida CPF correto', () => {
    assert.strictEqual(isValid('52998224725'), true);
  });

  it('valida CPF com formatação', () => {
    assert.strictEqual(isValid('529.982.247-25'), true);
  });

  it('rejeita CPF com dígitos iguais', () => {
    assert.strictEqual(isValid('11111111111'), false);
    assert.strictEqual(isValid('00000000000'), false);
  });

  it('rejeita CPF com tamanho errado', () => {
    assert.strictEqual(isValid('1234567890'), false);
    assert.strictEqual(isValid('123456789012'), false);
  });

  it('rejeita CPF com dígito verificador errado', () => {
    assert.strictEqual(isValid('52998224726'), false);
  });

  it('rejeita null/undefined/vazio', () => {
    assert.strictEqual(isValid(null), false);
    assert.strictEqual(isValid(undefined), false);
    assert.strictEqual(isValid(''), false);
  });

  it('clean remove formatação', () => {
    assert.strictEqual(clean('529.982.247-25'), '52998224725');
    assert.strictEqual(clean(null), null);
  });
});

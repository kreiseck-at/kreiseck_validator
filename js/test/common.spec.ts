import { describe, it, expect } from 'vitest';
import { valid, invalid, FormatError } from '../src/index';

describe('common', () => {
  it('builds valid/invalid results', () => {
    const v = valid('X', []);
    expect(v.ok).toBe(true);
    const i = invalid('emailEmpty', 'Email is empty.');
    expect(i.ok).toBe(false);
    if (!i.ok) expect(i.issues[0].code).toBe('emailEmpty');
  });
  it('FormatError carries a name', () => {
    expect(new FormatError('x').name).toBe('FormatError');
  });
});

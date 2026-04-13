import pg from 'pg';
import jwt from 'jsonwebtoken';
import { isValid, clean } from './cpf-validator.mjs';

const { Pool } = pg;

let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'oficina',
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      max: 3,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 60000,
      ssl: { rejectUnauthorized: false },
    });
  }
  return pool;
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
    body: JSON.stringify(body),
  };
}

export async function handler(event) {
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return response(200, {});
  }

  let body;
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch {
    return response(400, { error: 'Body inválido' });
  }

  const cpf = clean(body?.cpf);

  // 1. Validar CPF
  if (!isValid(cpf)) {
    return response(400, { error: 'CPF inválido' });
  }

  const db = getPool();

  try {
    // 2. Consultar existência do cliente na base
    const clientResult = await db.query(
      'SELECT client_id, name, cpf FROM client WHERE cpf = $1',
      [cpf]
    );

    if (clientResult.rows.length === 0) {
      return response(404, { error: 'Cliente não encontrado' });
    }

    const client = clientResult.rows[0];

    // 2b. Consultar status do usuário vinculado
    const userResult = await db.query(
      'SELECT user_id, username, role, active FROM users WHERE client_id = $1',
      [client.client_id]
    );

    const user = userResult.rows[0];

    if (user && !user.active) {
      return response(403, { error: 'Usuário inativo' });
    }

    // 3. Gerar JWT com mesmas claims do JwtTokenProvider.java
    const token = jwt.sign(
      {
        userId: user?.user_id || null,
        role: user?.role || 'CLIENTE',
        clientId: client.client_id,
      },
      process.env.JWT_SECRET,
      {
        subject: user?.username || cpf,
        expiresIn: '1h',
      }
    );

    return response(200, {
      token,
      expiresIn: 3600,
      client: {
        clientId: client.client_id,
        name: client.name,
        cpf: client.cpf,
      },
    });
  } catch (err) {
    console.error('Erro ao processar autenticação:', err);
    return response(500, { error: 'Erro interno ao processar autenticação' });
  }
}

// Connexion PostgreSQL (pool de connexions partagé par toute l'application)
const { Pool, types } = require('pg');

// Les colonnes DATE (OID 1082) sont renvoyées telles quelles ("2026-10-09")
// au lieu d'objets Date, ce qui évite les problèmes de fuseau horaire.
types.setTypeParser(1082, (v) => v);

// Connexion : DATABASE_URL si elle est fournie, sinon les variables PGHOST, PGUSER, PGPASSWORD, PGDATABASE
const pool = new Pool(process.env.DATABASE_URL ? { connectionString: process.env.DATABASE_URL } : {});
module.exports = pool;

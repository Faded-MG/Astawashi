exports.up = (pgm) => {
  pgm.createExtension('pgcrypto', { ifNotExists: true });

  pgm.createTable(
    'shops',
    {
      id: {
        type: 'uuid',
        primaryKey: true,
        default: pgm.func('gen_random_uuid()'),
      },
      name: { type: 'text', notNull: true },
      created_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
    },
    { ifNotExists: true },
  );

  pgm.createTable(
    'users',
    {
      id: {
        type: 'uuid',
        primaryKey: true,
        default: pgm.func('gen_random_uuid()'),
      },
      phone: { type: 'text', notNull: true, unique: true },
      pin_hash: { type: 'text', notNull: true },
      shop_id: {
        type: 'uuid',
        notNull: true,
        references: 'shops(id)',
        onDelete: 'CASCADE',
      },
      created_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
    },
    { ifNotExists: true },
  );

  pgm.createTable(
    'refresh_tokens',
    {
      id: {
        type: 'uuid',
        primaryKey: true,
        default: pgm.func('gen_random_uuid()'),
      },
      user_id: {
        type: 'uuid',
        notNull: true,
        references: 'users(id)',
        onDelete: 'CASCADE',
      },
      family_id: { type: 'text', notNull: true },
      token_hash: { type: 'text', notNull: true, unique: true },
      revoked_at: { type: 'timestamptz' },
      replaced_by_token_id: { type: 'uuid', references: 'refresh_tokens(id)' },
      rotated_at: { type: 'timestamptz' },
      expires_at: { type: 'timestamptz', notNull: true },
      created_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
    },
    { ifNotExists: true },
  );

  pgm.createIndex('refresh_tokens', 'user_id');
  pgm.createIndex('refresh_tokens', 'family_id');
  pgm.createIndex('refresh_tokens', 'expires_at');
};

exports.down = (pgm) => {
  pgm.dropTable('refresh_tokens', { ifExists: true, cascade: true });
  pgm.dropTable('users', { ifExists: true, cascade: true });
  pgm.dropTable('shops', { ifExists: true, cascade: true });
};

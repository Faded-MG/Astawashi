exports.up = (pgm) => {
  pgm.createSequence('change_seq', { ifNotExists: true, start: 1, increment: 1 });

  pgm.createTable(
    'customers',
    {
      id: {
        type: 'uuid',
        primaryKey: true,
      },
      shop_id: {
        type: 'uuid',
        notNull: true,
        references: 'shops(id)',
        onDelete: 'CASCADE',
      },
      name: { type: 'text', notNull: true },
      phone: { type: 'text' },
      note: { type: 'text' },
      created_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
      updated_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
      deleted_at: { type: 'timestamptz' },
      synced_at: { type: 'timestamptz' },
      server_seq: {
        type: 'bigint',
        notNull: true,
        default: pgm.func('nextval(\'change_seq\')'),
      },
    },
    { ifNotExists: true },
  );

  pgm.createTable(
    'ledger_entries',
    {
      id: {
        type: 'uuid',
        primaryKey: true,
      },
      shop_id: {
        type: 'uuid',
        notNull: true,
        references: 'shops(id)',
        onDelete: 'CASCADE',
      },
      customer_id: {
        type: 'uuid',
        notNull: true,
        references: 'customers(id)',
        onDelete: 'CASCADE',
      },
      kind: {
        type: 'text',
        notNull: true,
        check: "kind IN ('credit', 'payment', 'reversal')",
      },
      amount_santim: {
        type: 'integer',
        notNull: true,
      },
      delta_santim: { type: 'integer', notNull: true },
      reverses_id: { type: 'uuid', references: 'ledger_entries(id)' },
      note: { type: 'text' },
      occurred_at: {
        type: 'timestamptz',
        notNull: true,
      },
      created_at: {
        type: 'timestamptz',
        notNull: true,
        default: pgm.func('NOW()'),
      },
      device_id: { type: 'text', notNull: true },
      synced_at: { type: 'timestamptz' },
      server_seq: {
        type: 'bigint',
        notNull: true,
        default: pgm.func('nextval(\'change_seq\')'),
      },
    },
    { ifNotExists: true },
  );

  pgm.createIndex('customers', 'shop_id');
  pgm.createIndex('customers', ['shop_id', 'server_seq']);
  pgm.createIndex('ledger_entries', 'shop_id');
  pgm.createIndex('ledger_entries', 'customer_id');
  pgm.createIndex('ledger_entries', 'reverses_id', { unique: true, where: 'reverses_id IS NOT NULL' });
  pgm.createIndex('ledger_entries', ['shop_id', 'server_seq']);
};

exports.down = (pgm) => {
  pgm.dropTable('ledger_entries', { ifExists: true, cascade: true });
  pgm.dropTable('customers', { ifExists: true, cascade: true });
  pgm.dropSequence('change_seq', { ifExists: true, cascade: true });
};

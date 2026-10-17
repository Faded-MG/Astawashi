exports.up = (pgm) => {
  pgm.sql(`
    ALTER TABLE customers
      ADD CONSTRAINT customers_shop_id_id_unique UNIQUE (shop_id, id);

    ALTER TABLE ledger_entries
      ADD CONSTRAINT ledger_entries_shop_id_id_unique UNIQUE (shop_id, id),
      ADD CONSTRAINT ledger_entries_money_semantics_check CHECK (
        amount_santim > 0 AND (
          (kind = 'credit' AND delta_santim = amount_santim AND reverses_id IS NULL)
          OR
          (kind = 'payment' AND delta_santim = -amount_santim AND reverses_id IS NULL)
          OR
          (kind = 'reversal' AND reverses_id IS NOT NULL)
        )
      ),
      ADD CONSTRAINT ledger_entries_shop_customer_fk
        FOREIGN KEY (shop_id, customer_id)
        REFERENCES customers (shop_id, id)
        ON DELETE RESTRICT,
      ADD CONSTRAINT ledger_entries_shop_reversal_fk
        FOREIGN KEY (shop_id, reverses_id)
        REFERENCES ledger_entries (shop_id, id)
        ON DELETE RESTRICT;

    CREATE FUNCTION validate_ledger_reversal()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      original ledger_entries%ROWTYPE;
    BEGIN
      IF NEW.kind <> 'reversal' THEN
        RETURN NEW;
      END IF;

      SELECT * INTO original
      FROM ledger_entries
      WHERE shop_id = NEW.shop_id AND id = NEW.reverses_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'reversal target does not exist in this shop';
      END IF;
      IF original.kind = 'reversal' THEN
        RAISE EXCEPTION 'reversal entries cannot reverse another reversal';
      END IF;
      IF original.customer_id <> NEW.customer_id THEN
        RAISE EXCEPTION 'reversal customer must match the original entry customer';
      END IF;
      IF NEW.amount_santim <> original.amount_santim
         OR NEW.delta_santim <> -original.delta_santim THEN
        RAISE EXCEPTION 'reversal amount and delta must negate the original entry';
      END IF;

      RETURN NEW;
    END;
    $$;

    CREATE FUNCTION prevent_ledger_entry_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'ledger_entries is append-only';
    END;
    $$;

    CREATE TRIGGER ledger_entries_append_only
      BEFORE UPDATE OR DELETE ON ledger_entries
      FOR EACH ROW
      EXECUTE FUNCTION prevent_ledger_entry_mutation();

    CREATE TRIGGER ledger_entries_validate_reversal
      BEFORE INSERT ON ledger_entries
      FOR EACH ROW
      EXECUTE FUNCTION validate_ledger_reversal();
  `);
};

exports.down = (pgm) => {
  pgm.sql(`
    DROP TRIGGER IF EXISTS ledger_entries_validate_reversal ON ledger_entries;
    DROP TRIGGER IF EXISTS ledger_entries_append_only ON ledger_entries;
    DROP FUNCTION IF EXISTS validate_ledger_reversal();
    DROP FUNCTION IF EXISTS prevent_ledger_entry_mutation();

    ALTER TABLE ledger_entries
      DROP CONSTRAINT IF EXISTS ledger_entries_shop_reversal_fk,
      DROP CONSTRAINT IF EXISTS ledger_entries_shop_customer_fk,
      DROP CONSTRAINT IF EXISTS ledger_entries_money_semantics_check,
      DROP CONSTRAINT IF EXISTS ledger_entries_shop_id_id_unique;
    ALTER TABLE customers
      DROP CONSTRAINT IF EXISTS customers_shop_id_id_unique;
  `);
};

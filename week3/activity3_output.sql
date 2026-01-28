--TASK 1 PO
CREATE OR REPLACE FUNCTION log_product_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- INSERT
    IF TG_OP = 'INSERT' THEN
        INSERT INTO products_audit (
            product_id,
            change_type,
            new_name,
            new_price
        )
        VALUES (
            NEW.product_id,
            'INSERT',
            NEW.name,
            NEW.price
        );

        RETURN NEW;

    -- DELETE
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO products_audit (
            product_id,
            change_type,
            old_name,
            old_price
        )
        VALUES (
            OLD.product_id,
            'DELETE',
            OLD.name,
            OLD.price
        );

        RETURN OLD;

    -- UPDATE
    ELSIF TG_OP = 'UPDATE' THEN

        IF NEW.name IS DISTINCT FROM OLD.name
           OR NEW.price IS DISTINCT FROM OLD.price THEN

            INSERT INTO products_audit (
                product_id,
                change_type,
                old_name,
                new_name,
                old_price,
                new_price
            )
            VALUES (
                OLD.product_id,
                'UPDATE',
                OLD.name,
                NEW.name,
                OLD.price,
                NEW.price
            );
        END IF;

        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

--TASK 2 PO (CREATE TRIGGER)

CREATE TRIGGER product_audit_trigger
AFTER INSERT OR UPDATE OR DELETE
ON products
FOR EACH ROW
EXECUTE FUNCTION log_product_changes();

--TASK 3 PO (Test Trigger)

-- 1. INSERT test
INSERT INTO products (name, description, price, stock_quantity)
VALUES ('Miniature Thingamabob', 'A very small thingamabob.', 4.99, 500);

-- 2. UPDATE with meaningful change
UPDATE products
SET price = 225.00, name = 'Mega Gadget v2'
WHERE name = 'Mega Gadget';

-- 3. UPDATE with no meaningful change (should NOT log)
UPDATE products
SET description = 'An even simpler gizmo for all your daily tasks.'
WHERE name = 'Basic Gizmo';

-- 4. DELETE test
DELETE FROM products
WHERE name = 'Super Widget';

--TASK 4 (VERIFY)

SELECT * 
FROM products_audit
ORDER BY audit_id;

--BONUS

CREATE OR REPLACE FUNCTION set_last_modified()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.last_modified = NOW();
    RETURN NEW;
END;
$$;

-----

CREATE TRIGGER set_last_modified_trigger
BEFORE UPDATE
ON products
FOR EACH ROW
EXECUTE FUNCTION set_last_modified();



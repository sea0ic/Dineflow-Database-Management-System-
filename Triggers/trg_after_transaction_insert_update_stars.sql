DELIMITER $$
CREATE TRIGGER trg_after_transaction_insert_update_stars
AFTER INSERT ON payment_transaction
FOR EACH ROW
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_current_stars INT;
    DECLARE v_stars_to_add INT;

    IF NEW.transaction_status = 'COMPLETED' THEN
        
        SELECT customer_id, stars_earned 
        INTO v_customer_id, v_stars_to_add
        FROM customer_order
        WHERE order_id = NEW.order_id;
        
        IF v_customer_id IS NOT NULL THEN
            
            -- Get current star balance
            SELECT total_stars INTO v_current_stars
            FROM customer
            WHERE customer_id = v_customer_id;
            
            UPDATE customer
            SET total_stars = total_stars + v_stars_to_add,
                last_order_date = CURRENT_DATE,
                total_lifetime_orders = total_lifetime_orders + 1,
                is_vip = IF(total_stars + v_stars_to_add >= 100, TRUE, FALSE)
            WHERE customer_id = v_customer_id;
            
            INSERT INTO loyalty_star_transaction (
                customer_id,
                transaction_type,
                star_amount,
                balance_before,
                balance_after,
                order_id,
                transaction_id,
                transaction_date,
                transaction_time
            ) VALUES (
                v_customer_id,
                'EARNED',
                v_stars_to_add,
                v_current_stars,
                v_current_stars + v_stars_to_add,
                NEW.order_id,
                NEW.transaction_id,
                NEW.transaction_date,
                NEW.transaction_time
            );
        END IF;
    END IF;
END$$

DELIMITER ;
DELIMITER $$
CREATE TRIGGER trg_after_refund_approved_reverse_stars
AFTER UPDATE ON refund
FOR EACH ROW
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_current_stars INT;
    DECLARE v_stars_to_reverse INT;
    
    -- Only process when refund is approved
    IF NEW.approval_status = 'APPROVED' AND OLD.approval_status = 'PENDING' THEN
        
        -- Get customer_id and stars from the refunded order
        SELECT customer_id, stars_earned 
        INTO v_customer_id, v_stars_to_reverse
        FROM customer_order
        WHERE order_id = NEW.order_id;
        
        -- Only process if customer exists
        IF v_customer_id IS NOT NULL AND v_stars_to_reverse > 0 THEN
            
            -- Get current star balance
            SELECT total_stars INTO v_current_stars
            FROM customer
            WHERE customer_id = v_customer_id;
            
            -- Update customer stars (cannot go below 0)
            UPDATE customer
            SET total_stars = GREATEST(0, total_stars - v_stars_to_reverse),
                is_vip = IF(GREATEST(0, total_stars - v_stars_to_reverse) >= 100, TRUE, FALSE)
            WHERE customer_id = v_customer_id;
            
            -- Create audit record for reversal
            INSERT INTO loyalty_star_transaction (
                customer_id,
                transaction_type,
                star_amount,
                balance_before,
                balance_after,
                order_id,
                refund_id,
                transaction_date,
                transaction_time,
                notes
            ) VALUES (
                v_customer_id,
                'REVERSED',
                -v_stars_to_reverse,
                v_current_stars,
                GREATEST(0, v_current_stars - v_stars_to_reverse),
                NEW.order_id,
                NEW.refund_id,
                NEW.refund_date,
                NEW.refund_time,
                CONCAT('Stars reversed due to refund: ', NEW.refund_reason)
            );
            
            UPDATE refund
            SET stars_reversed = v_stars_to_reverse
            WHERE refund_id = NEW.refund_id;
            
        END IF;
    END IF;
END$$

DELIMITER ;
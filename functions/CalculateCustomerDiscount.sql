use dineflow;
DELIMITER $$
CREATE FUNCTION CalculateCustomerDiscount(p_customer_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_stars INT;
    DECLARE v_discount DECIMAL(5,2);
    -- Get customer's total stars
    SELECT total_stars INTO v_total_stars
    FROM customer
    WHERE customer_id = p_customer_id;
    -- Handle NULL (customer not found)
    IF v_total_stars IS NULL THEN
        RETURN 0.00;
    END IF;
    -- Calculate discount based on star tiers
    IF v_total_stars >= 100 THEN
        SET v_discount = 20.00;
    ELSEIF v_total_stars >= 50 THEN
        SET v_discount = 15.00;
    ELSEIF v_total_stars >= 25 THEN
        SET v_discount = 10.00;
    ELSEIF v_total_stars >= 10 THEN
        SET v_discount = 5.00;
    ELSE
        SET v_discount = 0.00;
    END IF;
    
    RETURN v_discount;
END$$

DELIMITER ;
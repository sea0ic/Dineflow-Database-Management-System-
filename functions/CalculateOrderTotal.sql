use dineflow;
DELIMITER $$

CREATE FUNCTION CalculateOrderTotal(
    p_subtotal DECIMAL(10,2),
    p_discount_amount DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_taxable_amount DECIMAL(10,2);
    DECLARE v_tax_amount DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    
    -- Calculate taxable amount after discount
    SET v_taxable_amount = p_subtotal - p_discount_amount;
    
    -- Calculate 10% tax
    SET v_tax_amount = ROUND(v_taxable_amount * 0.10, 2);
    
    -- Calculate final total
    SET v_total = v_taxable_amount + v_tax_amount;
    
    RETURN v_total;
END$$

DELIMITER ;
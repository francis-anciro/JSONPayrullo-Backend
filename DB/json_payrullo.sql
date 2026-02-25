-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Feb 25, 2026 at 05:14 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `json_payrullo`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `deleteUser`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `deleteUser` (IN `p_user_id` INT)   BEGIN
    DELETE FROM users WHERE User_ID = p_user_id;
END$$

DROP PROCEDURE IF EXISTS `employeeList_UpdateEmploymentStatus`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `employeeList_UpdateEmploymentStatus` (IN `p_code` VARCHAR(50), IN `p_status` VARCHAR(50))   BEGIN

    UPDATE employees 

    SET employment_status = p_status 

    WHERE employee_code = p_code;

END$$

DROP PROCEDURE IF EXISTS `employeeTapIn`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `employeeTapIn` (IN `p_EmployeeID` INT)   BEGIN
    DECLARE v_time_start TIME;
    DECLARE v_current TIME;
    DECLARE v_status VARCHAR(10);

    
    SELECT s.time_start
    INTO v_time_start
    FROM employee_shifts es
    INNER JOIN shifts s ON es.Shift_ID = s.Shift_ID
    WHERE es.Employee_ID = p_EmployeeID
    ORDER BY es.start_date DESC
    LIMIT 1;

    SET v_current = CURTIME();

    
    IF v_current <= v_time_start THEN
        SET v_status = 'present';
    ELSE
        SET v_status = 'late';
    END IF;

    
    INSERT INTO attendance (Employee_ID, attendance_date, time_in, status)
    VALUES (p_EmployeeID, CURDATE(), v_current, v_status);

END$$

DROP PROCEDURE IF EXISTS `employeeTapOut`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `employeeTapOut` (IN `p_EmployeeID` INT)   BEGIN
    DECLARE v_time_out TIME;

    SET v_time_out = CURTIME();

    UPDATE attendance
    SET time_out = v_time_out
    WHERE Employee_ID = p_EmployeeID
    AND attendance_date = CURDATE()
    AND (time_out IS NULL OR time_out = '00:00:00');
END$$

DROP PROCEDURE IF EXISTS `generatePayrollRuns`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `generatePayrollRuns` (IN `p_PayrollPeriod_ID` INT, IN `p_generated_by` INT)   BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_employee_id INT;
    DECLARE v_basic_salary DECIMAL(10,2);
    DECLARE v_total_worked DECIMAL(10,2);
    DECLARE v_regular_hours DECIMAL(10,2);
    DECLARE v_overtime_hours DECIMAL(10,2);
    DECLARE v_daily_rate DECIMAL(10,2);
    DECLARE v_hourly_rate DECIMAL(10,2);
    DECLARE v_overtime_pay DECIMAL(10,2);
    DECLARE v_period_start DATE;
    DECLARE v_period_end DATE;

    DECLARE emp_cursor CURSOR FOR
        SELECT Employee_ID, basic_salary
        FROM employees
        WHERE employment_status = 'active';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SELECT period_start, period_end
    INTO v_period_start, v_period_end
    FROM payroll_periods
    WHERE PayrollPeriod_ID = p_PayrollPeriod_ID;

    DELETE FROM payroll_runs WHERE PayrollPeriod_ID = p_PayrollPeriod_ID;

    OPEN emp_cursor;

    read_loop: LOOP
        FETCH emp_cursor INTO v_employee_id, v_basic_salary;
        IF done THEN LEAVE read_loop; END IF;

        SELECT COALESCE(SUM(worked_hours), 0) INTO v_total_worked
        FROM attendance
        WHERE Employee_ID = v_employee_id
        AND attendance_date BETWEEN v_period_start AND v_period_end
        AND worked_hours IS NOT NULL;

        SET v_regular_hours  = LEAST(v_total_worked, 8 * (DATEDIFF(v_period_end, v_period_start) + 1));
        SET v_overtime_hours = GREATEST(v_total_worked - v_regular_hours, 0);

        SET v_daily_rate   = v_basic_salary / 26;
        SET v_hourly_rate  = v_daily_rate / 8;
        SET v_overtime_pay = v_overtime_hours * (v_hourly_rate * 1.25);

        INSERT INTO payroll_runs (
            PayrollPeriod_ID, Employee_ID, basic_pay,
            overtime_pay, allowances_total, deductions_total, generated_by
        ) VALUES (
            p_PayrollPeriod_ID, v_employee_id, v_basic_salary,
            v_overtime_pay, 0.00, 0.00, p_generated_by
        );
    END LOOP;

    CLOSE emp_cursor;

    
    INSERT INTO payslips (PayrollRun_ID)
    SELECT PayrollRun_ID 
    FROM payroll_runs 
    WHERE PayrollPeriod_ID = p_PayrollPeriod_ID 
    AND PayrollRun_ID NOT IN (SELECT PayrollRun_ID FROM payslips);

    UPDATE payroll_periods SET status = 'processed'
    WHERE PayrollPeriod_ID = p_PayrollPeriod_ID;

END$$

DROP PROCEDURE IF EXISTS `getAllAdmins`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllAdmins` ()   BEGIN
    SELECT
        User_ID,
        username,
        email,
        role,
        is_active,
        created_at
    FROM users
    WHERE role = 'admin'
    ORDER BY created_at DESC;
END$$

DROP PROCEDURE IF EXISTS `getAllEmployeeProfiles`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllEmployeeProfiles` ()   BEGIN
    SELECT
        e.Employee_ID,
        e.User_ID,
        u.username,
        u.email,
        u.role,
 
        CONCAT(e.first_name, ' ',
               IFNULL(CONCAT(e.middle_name, ' '), ''),
               e.last_name) AS full_name,
 
        d.Department_ID,
        d.name AS department_name,
 
        p.Position_ID,
        p.title AS position_title,
 
        et.EmployType_ID,
        et.name AS employment_type,
 
        e.employment_status,
        e.hire_date,
        e.basic_salary
 
    FROM employees e
    INNER JOIN users u ON u.User_ID = e.User_ID
    INNER JOIN departments d ON d.Department_ID = e.Department_ID
    INNER JOIN positions p ON p.Position_ID = e.Position_ID
    INNER JOIN employment_types et ON et.EmployType_ID = e.employment_type_id
 
    ORDER BY e.Employee_ID DESC;
END$$

DROP PROCEDURE IF EXISTS `getAllEmployees`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllEmployees` ()   BEGIN
    SELECT
        User_ID,
        username,
        email,
        role,
        is_active,
        created_at
    FROM users
    WHERE role = 'employee'
    ORDER BY created_at DESC;
END$$

DROP PROCEDURE IF EXISTS `getAllManagers`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllManagers` ()   BEGIN
    SELECT
        User_ID,
        username,
        email,
        role,
        is_active,
        created_at
    FROM users
    WHERE role = 'manager'
    ORDER BY created_at DESC;
END$$

DROP PROCEDURE IF EXISTS `getAllManagersWithDepartment`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllManagersWithDepartment` ()   BEGIN
    SELECT
        d.Department_ID,
        d.name AS department_name,
 
        u.User_ID AS manager_user_id,
        u.username AS manager_username,
        u.email AS manager_email,
        u.role AS manager_role
 
    FROM departments d
    LEFT JOIN users u ON u.User_ID = d.manager_user_id
 
    ORDER BY d.name ASC;
END$$

DROP PROCEDURE IF EXISTS `getAllUsers`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getAllUsers` ()   BEGIN
    SELECT
        User_ID,
        username,
        email,
        role,
        is_active,
        created_at
    FROM users
    ORDER BY created_at DESC;
END$$

DROP PROCEDURE IF EXISTS `getEmployeeProfileByUserId`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getEmployeeProfileByUserId` (IN `p_user_id` INT)   BEGIN
    SELECT
        e.Employee_ID,
        e.User_ID,
        u.username,
        u.email,
        u.role,
 
        e.first_name,
        e.middle_name,
        e.last_name,
        e.phone,
        e.address,
        e.birthdate,
 
        d.Department_ID,
        d.name AS department_name,
 
        p.Position_ID,
        p.title AS position_title,
 
        et.EmployType_ID,
        et.name AS employment_type,
 
        e.hire_date,
        e.employment_status,
        e.basic_salary
 
    FROM employees e
    INNER JOIN users u ON u.User_ID = e.User_ID
    INNER JOIN departments d ON d.Department_ID = e.Department_ID
    INNER JOIN positions p ON p.Position_ID = e.Position_ID
    INNER JOIN employment_types et ON et.EmployType_ID = e.employment_type_id
 
    WHERE e.User_ID = p_user_id
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `getUserById`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getUserById` (IN `p_user_id` INT)   BEGIN
    SELECT 
        User_ID,
        username,
        email,
        role,
        is_active,
        created_at
    FROM users
    WHERE User_ID = p_user_id
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `getUserRowByUsername`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `getUserRowByUsername` (IN `p_username` VARCHAR(50))   BEGIN

    SELECT

        id,

        username,

        email,

        password_hash,

        role,

        is_active,

        created_at

    FROM users

    WHERE username = p_username

    LIMIT 1;

END$$

DROP PROCEDURE IF EXISTS `insertUser`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `insertUser` (IN `p_username` VARCHAR(50), IN `p_email` VARCHAR(120), IN `p_password` VARCHAR(255), IN `p_role` ENUM('admin','manager','employee'))   BEGIN
    INSERT INTO users (username, email, password_hash, role, is_active) 
    VALUES (p_username, p_email, p_password, p_role, 1);
END$$

DROP PROCEDURE IF EXISTS `login_getUserRowByEmail`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `login_getUserRowByEmail` (IN `p_login` VARCHAR(120))   BEGIN
    SELECT
        u.User_ID,
        u.username,
        u.email,
        u.password_hash,
        u.role,
        u.is_active,
        e.Employee_ID, 
        e.employment_status
    FROM users u
    INNER JOIN employees e ON u.User_ID = e.User_ID
    WHERE u.username = p_login OR u.email = p_login
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_AssignDepartmentManager`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_AssignDepartmentManager` (IN `p_employee_code` VARCHAR(50), IN `p_department_id` INT)   BEGIN
    DECLARE v_new_emp_id INT;
    DECLARE v_new_user_id INT;
    DECLARE v_old_emp_id INT;

    
    SELECT department_manager_id INTO v_old_emp_id 
    FROM departments 
    WHERE Department_ID = p_department_id;

    IF v_old_emp_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Manager assignment failed. A manager is currently assigned.';
    END IF;

    
    SELECT Employee_ID, User_ID INTO v_new_emp_id, v_new_user_id 
    FROM employees 
    WHERE employee_code = p_employee_code;

    IF v_new_emp_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Employee code not found.';
    END IF;

    
    START TRANSACTION;

    UPDATE users SET role = 'manager' WHERE User_ID = v_new_user_id;
    UPDATE departments SET department_manager_id = v_new_emp_id WHERE Department_ID = p_department_id;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_DeleteUserByCode`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_DeleteUserByCode` (IN `p_employee_code` VARCHAR(50))   BEGIN
    DECLARE v_user_id INT;

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delete failed. Transaction rolled back.';
    END;

    START TRANSACTION;

    
    SELECT User_ID INTO v_user_id FROM employees WHERE employee_code = p_employee_code;

    
    IF v_user_id IS NOT NULL THEN
        
        DELETE FROM leave_balances 
        WHERE Employee_ID = (SELECT Employee_ID FROM employees WHERE employee_code = p_employee_code);

        
        DELETE FROM employee_shifts 
        WHERE Employee_ID = (SELECT Employee_ID FROM employees WHERE employee_code = p_employee_code);

        
        DELETE FROM employees WHERE employee_code = p_employee_code;

        
        DELETE FROM users WHERE User_ID = v_user_id;
    END IF;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_InsertNewEmployee`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_InsertNewEmployee` (IN `p_username` VARCHAR(50), IN `p_email` VARCHAR(120), IN `p_password_hash` VARCHAR(255), IN `p_role` VARCHAR(20), IN `p_employee_code` VARCHAR(20), IN `p_first_name` VARCHAR(50), IN `p_middle_name` VARCHAR(50), IN `p_last_name` VARCHAR(50), IN `p_phone` VARCHAR(20), IN `p_address` VARCHAR(120), IN `p_birthdate` DATE, IN `p_hire_date` DATE, IN `p_employment_type` VARCHAR(50), IN `p_department_id` INT, IN `p_position_id` INT, IN `p_basic_salary` DECIMAL(10,2), IN `p_shift_id` INT)   BEGIN
    DECLARE v_user_id INT;
    DECLARE v_employee_id INT;
    DECLARE v_existing_mgr INT;
 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
 
    START TRANSACTION;
 
    IF p_role = 'manager' THEN
        SELECT department_manager_id
        INTO v_existing_mgr
        FROM departments
        WHERE Department_ID = p_department_id;
 
        IF v_existing_mgr IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'This department already has a manager assigned.';
        END IF;
    END IF;
 
    INSERT INTO users (username, email, password_hash, role, is_active)
    VALUES (p_username, p_email, p_password_hash, p_role, 1);
 
    SET v_user_id = LAST_INSERT_ID();
 
    INSERT INTO employees (
        employee_code, User_ID, first_name, middle_name, last_name,
        phone, address, birthdate, hire_date, employment_status,
        employment_type, Department_ID, Position_ID, basic_salary
    )
    VALUES (
        p_employee_code, v_user_id, p_first_name, p_middle_name, p_last_name,
        p_phone, p_address, p_birthdate, p_hire_date, 'active',
        p_employment_type, p_department_id, p_position_id, p_basic_salary
    );
 
    SET v_employee_id = LAST_INSERT_ID();
 
    IF p_role = 'manager' THEN
        UPDATE departments
        SET department_manager_id = v_employee_id
        WHERE Department_ID = p_department_id;
    END IF;
 
    INSERT INTO employee_shifts (Employee_ID, Shift_ID, start_date)
    VALUES (v_employee_id, p_shift_id, p_hire_date)
    ON DUPLICATE KEY UPDATE Shift_ID = p_shift_id, start_date = p_hire_date;
 
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_ResignEmployee`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_ResignEmployee` (IN `p_employee_code` VARCHAR(50))   BEGIN
    DECLARE v_user_id INT;
    DECLARE v_emp_id INT;
    DECLARE v_dept_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    
    SELECT Employee_ID, User_ID, Department_ID 
    INTO v_emp_id, v_user_id, v_dept_id
    FROM employees 
    WHERE employee_code = p_employee_code;

    
    UPDATE users 
    SET is_active = 0 
    WHERE User_ID = v_user_id;

    
    UPDATE employees 
    SET employment_status = 'resigned' 
    WHERE employee_code = p_employee_code;

    
    UPDATE departments 
    SET department_manager_id = NULL 
    WHERE Department_ID = v_dept_id 
    AND department_manager_id = v_emp_id;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_UpdateContactDetails`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_UpdateContactDetails` (IN `p_Employee_ID` INT, IN `p_new_phone` VARCHAR(20))   BEGIN
    DECLARE v_old_phone VARCHAR(20);
    
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    
    SELECT phone INTO v_old_phone
    FROM employees
    WHERE Employee_ID = p_Employee_ID;

    
    IF p_new_phone != v_old_phone OR (v_old_phone IS NULL AND p_new_phone IS NOT NULL) THEN
        START TRANSACTION;

        UPDATE employees
        SET phone = p_new_phone
        WHERE Employee_ID = p_Employee_ID;

        INSERT INTO employee_edit_logs
            (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES
            (p_Employee_ID, p_Employee_ID, 'phone', v_old_phone, p_new_phone);

        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_UpdateEmployee`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_UpdateEmployee` (IN `p_employee_code` VARCHAR(50), IN `p_username` VARCHAR(50), IN `p_email` VARCHAR(255), IN `p_password_hash` VARCHAR(255), IN `p_role` VARCHAR(50), IN `p_first_name` VARCHAR(100), IN `p_last_name` VARCHAR(100), IN `p_phone` VARCHAR(20), IN `p_address` TEXT, IN `p_department_id` INT, IN `p_position_id` INT, IN `p_basic_salary` DECIMAL(10,2), IN `p_shift_id` INT, IN `p_changed_by` INT)   BEGIN
    DECLARE v_user_id           INT;
    DECLARE v_emp_id            INT;
    DECLARE v_old_role          VARCHAR(50);
    DECLARE v_old_username      VARCHAR(50);
    DECLARE v_old_email         VARCHAR(255);
    DECLARE v_old_first_name    VARCHAR(100);
    DECLARE v_old_last_name     VARCHAR(100);
    DECLARE v_old_phone         VARCHAR(20);
    DECLARE v_old_address       TEXT;
    DECLARE v_old_department_id INT;
    DECLARE v_old_position_id   INT;
    DECLARE v_old_basic_salary  DECIMAL(10,2);
    DECLARE v_old_shift_id      INT;
 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
 
    START TRANSACTION;
 
    
    SELECT e.Employee_ID, e.User_ID, u.role, u.username, u.email,
           e.first_name, e.last_name, e.phone, e.address,
           e.Department_ID, e.Position_ID, e.basic_salary
    INTO v_emp_id, v_user_id, v_old_role, v_old_username, v_old_email,
         v_old_first_name, v_old_last_name, v_old_phone, v_old_address,
         v_old_department_id, v_old_position_id, v_old_basic_salary
    FROM employees e
    JOIN users u ON e.User_ID = u.User_ID
    WHERE e.employee_code = p_employee_code;
 
    SELECT Shift_ID INTO v_old_shift_id
    FROM employee_shifts
    WHERE Employee_ID = v_emp_id;
 
    
    UPDATE users
    SET username      = p_username,
        email         = p_email,
        password_hash = COALESCE(p_password_hash, password_hash),
        role          = p_role
    WHERE User_ID = v_user_id;
 
    UPDATE employees
    SET first_name    = p_first_name,
        last_name     = p_last_name,
        phone         = p_phone,
        address       = p_address,
        Department_ID = p_department_id,
        Position_ID   = p_position_id,
        basic_salary  = p_basic_salary
    WHERE employee_code = p_employee_code;
 
    INSERT INTO employee_shifts (employee_id, shift_id)
    VALUES (v_emp_id, p_shift_id)
    ON DUPLICATE KEY UPDATE shift_id = p_shift_id;
 
    
    IF p_username != v_old_username THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'username', v_old_username, p_username);
    END IF;
 
    IF p_email != v_old_email THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'email', v_old_email, p_email);
    END IF;
 
    IF p_role != v_old_role THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'role', v_old_role, p_role);
    END IF;
 
    IF p_first_name != v_old_first_name THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'first_name', v_old_first_name, p_first_name);
    END IF;
 
    IF p_last_name != v_old_last_name THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'last_name', v_old_last_name, p_last_name);
    END IF;
 
    IF p_phone != v_old_phone THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'phone', v_old_phone, p_phone);
    END IF;
 
    IF p_address != v_old_address THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'address', v_old_address, p_address);
    END IF;
 
    IF p_department_id != v_old_department_id THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'department_id', v_old_department_id, p_department_id);
    END IF;
 
    IF p_position_id != v_old_position_id THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'position_id', v_old_position_id, p_position_id);
    END IF;
 
    IF p_basic_salary != v_old_basic_salary THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'basic_salary', v_old_basic_salary, p_basic_salary);
    END IF;
 
    IF p_shift_id != v_old_shift_id THEN
        INSERT INTO employee_edit_logs (Employee_ID, changed_by, field_name, old_value, new_value)
        VALUES (v_emp_id, p_changed_by, 'shift_id', v_old_shift_id, p_shift_id);
    END IF;
 
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `syncPayrollTotals`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `syncPayrollTotals` (IN `p_PayrollRun_ID` INT)   BEGIN
    UPDATE payroll_runs
    SET 
        allowances_total = (
            SELECT COALESCE(SUM(amount), 0) 
            FROM payroll_allowances 
            WHERE PayrollRun_ID = p_PayrollRun_ID
        ),
        deductions_total = (
            SELECT COALESCE(SUM(amount), 0) 
            FROM payroll_deductions 
            WHERE PayrollRun_ID = p_PayrollRun_ID
        )
    WHERE PayrollRun_ID = p_PayrollRun_ID;
END$$

DROP PROCEDURE IF EXISTS `updateUser`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `updateUser` (IN `p_id` INT, IN `p_username` VARCHAR(50), IN `p_email` VARCHAR(120), IN `p_role` ENUM('admin','manager','employee'), IN `p_active` TINYINT(1))   BEGIN
    UPDATE users 
    SET username = p_username, 
        email = p_email, 
        role = p_role, 
        is_active = p_active 
    WHERE User_ID = p_id;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `attendance`
--

DROP TABLE IF EXISTS `attendance`;
CREATE TABLE `attendance` (
  `Attendance_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `attendance_date` date NOT NULL,
  `time_in` time DEFAULT NULL,
  `time_out` time DEFAULT NULL,
  `status` enum('present','absent','late','on_leave') NOT NULL,
  `remarks` varchar(200) DEFAULT NULL,
  `total_hours` decimal(5,2) DEFAULT 0.00,
  `worked_hours` decimal(5,2) DEFAULT NULL,
  `overtime_hours` decimal(5,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendance`
--

INSERT INTO `attendance` (`Attendance_ID`, `Employee_ID`, `attendance_date`, `time_in`, `time_out`, `status`, `remarks`, `total_hours`, `worked_hours`, `overtime_hours`) VALUES
(1001, 1001, '2026-02-23', '16:46:30', '17:06:50', 'late', NULL, 0.34, 0.00, 0.00),
(1002, 1001, '2026-03-23', '09:00:08', '17:00:20', 'late', NULL, 8.00, 7.00, 0.00),
(1003, 1001, '2026-02-25', '12:26:06', '12:42:25', 'late', NULL, 0.27, 0.00, 0.00),
(1006, 1015, '2026-02-25', '19:16:29', '20:03:53', 'late', NULL, 0.79, 0.00, 0.00),
(1008, 1001, '2026-02-26', '09:00:53', '17:01:11', 'late', NULL, 8.01, 7.01, 0.00);

--
-- Triggers `attendance`
--
DROP TRIGGER IF EXISTS `trg_calculate_total_hours`;
DELIMITER $$
CREATE TRIGGER `trg_calculate_total_hours` BEFORE UPDATE ON `attendance` FOR EACH ROW BEGIN
    DECLARE v_break_minutes INT DEFAULT 60;

    IF NEW.time_out IS NOT NULL THEN
        
        SELECT s.break_minutes INTO v_break_minutes
        FROM employee_shifts es
        INNER JOIN shifts s ON es.Shift_ID = s.Shift_ID
        WHERE es.Employee_ID = NEW.Employee_ID
        ORDER BY es.start_date DESC LIMIT 1;

        
        SET NEW.total_hours = GREATEST(TIMESTAMPDIFF(SECOND, NEW.time_in, NEW.time_out) / 3600, 0);
        SET NEW.worked_hours = GREATEST(NEW.total_hours - (v_break_minutes / 60), 0);

        
        SET NEW.overtime_hours = GREATEST(NEW.worked_hours - 8, 0);
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

DROP TABLE IF EXISTS `departments`;
CREATE TABLE `departments` (
  `Department_ID` int(11) NOT NULL,
  `department_code` varchar(10) NOT NULL,
  `name` varchar(80) NOT NULL,
  `department_manager_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`Department_ID`, `department_code`, `name`, `department_manager_id`) VALUES
(1001, 'CREAPRO', 'Creative & Production', 1001),
(1002, 'CONTSOC', 'Content & Social Media', NULL),
(1003, 'ACCCLIE', 'Accounts & Client Services', 1013),
(1004, 'OPETECH', 'Operations & Technology', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `employees`
--

DROP TABLE IF EXISTS `employees`;
CREATE TABLE `employees` (
  `Employee_ID` int(11) NOT NULL,
  `employee_code` varchar(20) NOT NULL,
  `User_ID` int(11) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `middle_name` varchar(50) DEFAULT NULL,
  `last_name` varchar(50) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `address` varchar(120) NOT NULL,
  `birthdate` date NOT NULL,
  `hire_date` date NOT NULL,
  `employment_status` enum('active','on_leave','resigned') NOT NULL DEFAULT 'active',
  `Department_ID` int(11) NOT NULL,
  `Position_ID` int(11) NOT NULL,
  `basic_salary` decimal(10,2) NOT NULL DEFAULT 18000.00,
  `employment_type` enum('Contract / Freelancer','Full-time','Intern / Trainee','Part-time') DEFAULT NULL
) ;

--
-- Dumping data for table `employees`
--

INSERT INTO `employees` (`Employee_ID`, `employee_code`, `User_ID`, `first_name`, `middle_name`, `last_name`, `phone`, `address`, `birthdate`, `hire_date`, `employment_status`, `Department_ID`, `Position_ID`, `basic_salary`, `employment_type`) VALUES
(1001, 'CREAPRO-2026-001', 1001, 'Shu', NULL, 'Li', '09171234567', '123 Creative St, Manila', '1985-07-12', '2026-02-01', 'active', 1001, 1001, 45000.00, 'Full-time'),
(1002, 'CREAPRO-2026-002', 1002, 'David', 'K', 'OLD', '09179998888', '456 Creative St, Manila', '1990-05-23', '2026-02-02', 'active', 1002, 1005, 28000.00, 'Full-time'),
(1003, 'CONTSOC-2026-001', 1003, 'Emma', NULL, 'Sun', '09171239876', '789 Content Ave, Manila', '1992-11-15', '2026-02-03', 'active', 1003, 1010, 38000.00, 'Full-time'),
(1004, 'ACCCLIE-2026-001', 1004, 'Frank', NULL, 'Yap', '09172345678', '321 Account Rd, Manila', '1988-03-10', '2026-02-04', 'on_leave', 1003, 1009, 42000.00, 'Full-time'),
(1005, 'OPETECH-2026-001', 1005, 'Grace', 'H', 'Lim', '09173456789', '654 Tech Blvd, Manila', '1995-09-05', '2026-02-05', 'on_leave', 1004, 1011, 50000.00, 'Full-time'),
(1006, 'CREAPRO-2026-1006', 1007, 'Samuel', '', 'Jackson', '09175551234', '123 Pulp St, Manila', '2020-01-17', '2026-02-17', 'active', 1001, 1001, 35000.00, 'Full-time'),
(1011, 'CREAPRO-2026-1003', 1043, 'John', 'Middle', 'Doe', '09170001111', '789 Test St, Manila', '1995-01-01', '2026-02-21', 'active', 1001, 1002, 28000.00, NULL),
(1012, 'CONTSOC-2026-1012', 1044, 'Bruce', '', 'Banner', '09184445678', '789 Gamma Rd, QC', '2010-10-10', '2026-02-21', 'resigned', 1002, 1006, 123123.00, NULL),
(1013, 'ACCCLIE-2026-1013', 1045, 'Natasha', '', 'Romanoff', '09192223333', '321 Spy St, Makati', '2001-10-10', '2026-02-22', 'active', 1002, 1007, 200000.00, NULL),
(1014, 'CREAPRO-2026-1004', 1046, 'Ethan', '', 'Francisco', '09170002222', '1111, ABCD', '2001-10-10', '2026-02-22', 'active', 1001, 1003, 20000.00, NULL),
(1015, 'OPETECH-2026-1002', 1049, 'Zeit', '', '05', '09040404040', '222,sdsa', '2006-10-04', '2026-02-22', 'active', 1004, 1012, 100000.00, NULL),
(1016, 'OPETECH-2026-1016', 1051, 'Tony', 'User', 'Stark', '09998887766', 'Stark Tower, Makati', '1995-01-01', '2026-02-23', 'resigned', 1004, 1011, 35000.00, 'Full-time'),
(1017, 'OPETECH-2026-1017', 1053, 'Steve', 'User', 'Rogers', '09123456789', 'Brooklyn St, Makati', '1995-05-20', '2026-02-23', 'resigned', 1004, 1011, 25000.00, 'Full-time'),
(1018, 'CREAPRO-2026-1005', 1056, 'WAlter', 'Hartwell', 'White', '00000000000', 'jojin island', '2002-09-09', '2024-02-23', 'active', 1001, 1001, 200000.00, 'Full-time'),
(1019, 'CREAPRO-2026-1006', 1057, 'Jane', 'N', 'Doe', '09270615515', '654 Account Rd, Manila', '2007-11-05', '2026-02-23', 'active', 1001, 1001, 20000.00, 'Full-time'),
(1024, 'CONTSOC-2026-1005', 1062, 'Mary', 'Ann', 'Smith', '23123123123', '000', '2020-10-01', '2026-02-24', 'active', 1002, 1006, 23222.00, 'Full-time'),
(1025, 'OPETECH-2026-1005', 1063, 'Ethan', 'Ethan19', 'James', '09156667777', '456 Silver Oak, Mandaluyong', '2010-10-10', '2026-02-24', 'active', 1004, 1011, 100000.00, 'Full-time'),
(1026, 'OPETECH-2026-1006', 1065, 'Clark', 'Joseph', 'Kent', '09171112222', 'Smallville, Kansas', '1980-06-18', '2026-02-24', 'active', 1004, 1013, 65000.00, 'Full-time'),
(1027, 'ACCCLIE-2026-1003', 1069, 'Test', 'Employee', '1', '09171234565', '123 Side street', '2001-01-01', '2026-02-25', 'resigned', 1003, 1009, 50000.00, 'Full-time');

-- --------------------------------------------------------

--
-- Table structure for table `employee_edit_logs`
--

DROP TABLE IF EXISTS `employee_edit_logs`;
CREATE TABLE `employee_edit_logs` (
  `Log_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `changed_by` int(11) NOT NULL,
  `field_name` varchar(50) NOT NULL,
  `old_value` varchar(255) DEFAULT NULL,
  `new_value` varchar(255) DEFAULT NULL,
  `changed_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `employee_edit_logs`
--

INSERT INTO `employee_edit_logs` (`Log_ID`, `Employee_ID`, `changed_by`, `field_name`, `old_value`, `new_value`, `changed_at`) VALUES
(1, 1001, 1001, 'phone', '09171234567', '09171234568', '2026-02-25 17:12:45'),
(2, 1002, 1015, 'email', 'david.new@jsoncorp.com', 'david.old@jsoncorp.com', '2026-02-25 18:21:36'),
(3, 1002, 1015, 'last_name', 'Old', 'Santos', '2026-02-25 18:21:36'),
(4, 1002, 1015, 'last_name', 'Santos', 'OLD', '2026-02-25 18:33:56'),
(5, 1001, 1001, 'phone', '09171234568', '09171234567', '2026-02-26 17:02:25'),
(6, 1002, 1001, 'department_id', '1001', '1002', '2026-02-25 20:54:47'),
(7, 1002, 1001, 'position_id', '1002', '1005', '2026-02-25 20:54:47');

-- --------------------------------------------------------

--
-- Table structure for table `employee_shifts`
--

DROP TABLE IF EXISTS `employee_shifts`;
CREATE TABLE `employee_shifts` (
  `EmployShift_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `Shift_ID` int(11) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `employee_shifts`
--

INSERT INTO `employee_shifts` (`EmployShift_ID`, `Employee_ID`, `Shift_ID`, `start_date`, `end_date`) VALUES
(1001, 1001, 1001, '2026-02-01', NULL),
(1002, 1002, 1001, '2026-02-02', NULL),
(1003, 1003, 1002, '2026-02-03', NULL),
(1004, 1004, 1001, '2026-02-04', NULL),
(1005, 1005, 1003, '2026-02-05', NULL),
(1006, 1006, 1001, '2026-02-17', NULL),
(1011, 1011, 1001, '2026-02-21', NULL),
(1012, 1012, 1001, '2026-02-21', NULL),
(1013, 1013, 1001, '2026-02-22', NULL),
(1015, 1014, 1001, '2026-02-22', NULL),
(1016, 1015, 1001, '2026-02-22', NULL),
(1017, 1016, 1001, '2026-02-23', NULL),
(1019, 1017, 1001, '2026-02-23', NULL),
(1020, 1018, 1001, '2024-02-23', NULL),
(1025, 1019, 1001, '2026-02-23', NULL),
(1029, 1024, 1001, '2026-02-24', NULL),
(1031, 1025, 1001, '2026-02-24', NULL),
(1044, 1026, 1001, '2026-02-24', NULL),
(1055, 1027, 1001, '2026-02-25', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `leave_balances`
--

DROP TABLE IF EXISTS `leave_balances`;
CREATE TABLE `leave_balances` (
  `LeaveBal_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `LeaveType_ID` int(11) NOT NULL,
  `year` int(11) NOT NULL,
  `allocated_days` int(11) NOT NULL,
  `used_days` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leave_balances`
--

INSERT INTO `leave_balances` (`LeaveBal_ID`, `Employee_ID`, `LeaveType_ID`, `year`, `allocated_days`, `used_days`) VALUES
(1, 1002, 2, 2026, 10, 2),
(2, 1003, 4, 2026, 5, 0),
(3, 1004, 3, 2026, 30, 0),
(4, 1005, 1, 2026, 15, 3),
(5, 1006, 1, 2026, 15, 0),
(10, 1011, 1, 2026, 15, 0),
(11, 1012, 1, 2026, 15, 0),
(12, 1013, 1, 2026, 15, 0),
(13, 1014, 1, 2026, 15, 0),
(14, 1015, 1, 2026, 15, 0),
(15, 1016, 1, 2026, 15, 0),
(16, 1017, 1, 2026, 15, 0),
(17, 1018, 1, 2024, 15, 0),
(18, 1019, 1, 2026, 15, 0);

-- --------------------------------------------------------

--
-- Table structure for table `leave_requests`
--

DROP TABLE IF EXISTS `leave_requests`;
CREATE TABLE `leave_requests` (
  `LeaveReq_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `leave_type_id` int(11) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `reason` varchar(200) DEFAULT NULL,
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `requested_at` datetime NOT NULL DEFAULT current_timestamp(),
  `reviewed_by` int(11) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leave_requests`
--

INSERT INTO `leave_requests` (`LeaveReq_ID`, `Employee_ID`, `leave_type_id`, `start_date`, `end_date`, `reason`, `status`, `requested_at`, `reviewed_by`, `reviewed_at`) VALUES
(1, 1002, 2, '2026-03-10', '2026-03-12', 'Flu', 'approved', '2026-02-15 10:00:00', 1002, NULL),
(2, 1003, 4, '2026-03-15', '2026-03-15', 'Emergency', 'pending', '2026-02-20 11:00:00', NULL, NULL),
(3, 1004, 3, '2026-03-20', '2026-03-25', 'Personal reasons', 'pending', '2026-02-25 14:00:00', NULL, NULL),
(4, 1005, 1, '2026-03-05', '2026-03-10', 'Vacation', 'approved', '2026-02-12 09:30:00', 1002, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `leave_types`
--

DROP TABLE IF EXISTS `leave_types`;
CREATE TABLE `leave_types` (
  `LeaveType_ID` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `max_days_per_year` int(11) NOT NULL,
  `is_paid` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leave_types`
--

INSERT INTO `leave_types` (`LeaveType_ID`, `name`, `max_days_per_year`, `is_paid`) VALUES
(1, 'Vacation', 15, 1),
(2, 'Sick Leave', 10, 1),
(3, 'Unpaid Leave', 30, 0),
(4, 'Emergency', 5, 1);

-- --------------------------------------------------------

--
-- Table structure for table `payroll_adjustments`
--

DROP TABLE IF EXISTS `payroll_adjustments`;
CREATE TABLE `payroll_adjustments` (
  `adjustment_id` int(11) NOT NULL,
  `payroll_run_id` int(11) DEFAULT NULL,
  `type` enum('allowance','deduction') DEFAULT NULL,
  `description` varchar(100) DEFAULT NULL,
  `amount` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payroll_allowances`
--

DROP TABLE IF EXISTS `payroll_allowances`;
CREATE TABLE `payroll_allowances` (
  `PayrollAllowance_ID` int(11) NOT NULL,
  `PayrollRun_ID` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `amount` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payroll_allowances`
--

INSERT INTO `payroll_allowances` (`PayrollAllowance_ID`, `PayrollRun_ID`, `name`, `amount`) VALUES
(1001, 1001, 'Transport', 1000.00),
(1002, 1001, 'Meal', 1000.00),
(1003, 1002, 'Transport', 500.00),
(1004, 1003, 'Bonus', 500.00),
(1005, 1005, 'Housing', 1500.00),
(1006, 1033, 'Transportation', -1.00),
(1007, 1042, 'Transportation', 5000.00),
(1008, 1041, 'Performance Bonus', 1.00),
(1010, 1042, 'Internet Subsidy', 1500.00),
(1011, 1070, 'Performance Bonus', 10000.00),
(1012, 1001, 'Performance Bonus', 5000.00),
(1013, 1068, 'Transportation', 2000.00),
(1014, 1079, 'Performance Bonus', 50000.00),
(1015, 1096, 'Performance Bonus', 10000.00);

-- --------------------------------------------------------

--
-- Table structure for table `payroll_deductions`
--

DROP TABLE IF EXISTS `payroll_deductions`;
CREATE TABLE `payroll_deductions` (
  `PayrollDeduction_ID` int(11) NOT NULL,
  `PayrollRun_ID` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `amount` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payroll_deductions`
--

INSERT INTO `payroll_deductions` (`PayrollDeduction_ID`, `PayrollRun_ID`, `name`, `amount`) VALUES
(1001, 1001, 'Tax', 1500.00),
(1002, 1002, 'Tax', 500.00),
(1003, 1003, 'Tax', 800.00),
(1004, 1004, 'Tax', 1000.00),
(1005, 1005, 'Tax', 2000.00),
(1006, 1033, 'Tax', 10000.00),
(1007, 1042, 'Pag-IBIG', 10000.00),
(1008, 1041, 'Tax', 15000.00),
(1009, 1001, 'SSS Contribution', 1200.00),
(1010, 1070, 'SSS', 10000.00),
(1011, 1070, 'Tax', 5000.00),
(1012, 1068, 'SSS', 500.00),
(1013, 1067, 'Tax', 10000.00),
(1014, 1079, 'Tax', 10000.00),
(1015, 1096, 'Pag-IBIG', 500.00);

-- --------------------------------------------------------

--
-- Table structure for table `payroll_periods`
--

DROP TABLE IF EXISTS `payroll_periods`;
CREATE TABLE `payroll_periods` (
  `PayrollPeriod_ID` int(11) NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `pay_date` date NOT NULL,
  `status` enum('open','processed','released') NOT NULL DEFAULT 'open'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payroll_periods`
--

INSERT INTO `payroll_periods` (`PayrollPeriod_ID`, `period_start`, `period_end`, `pay_date`, `status`) VALUES
(1001, '2026-02-01', '2026-02-15', '2026-02-20', 'released'),
(1002, '2026-02-16', '2026-02-28', '2026-03-05', 'released'),
(1003, '2026-04-01', '2026-04-15', '2006-04-15', 'released'),
(1004, '2026-06-01', '2026-06-15', '2026-06-15', 'released'),
(1005, '2026-03-01', '2026-03-15', '2026-03-16', 'released'),
(1006, '2026-07-01', '2026-07-15', '2026-07-15', 'released'),
(1007, '2026-07-16', '2026-07-31', '2026-07-31', 'released'),
(1008, '2026-08-01', '2026-08-15', '2026-08-15', 'released'),
(1009, '2026-08-16', '2026-08-31', '2026-08-31', 'released'),
(1010, '2026-09-01', '2026-09-15', '2026-09-15', 'released');

-- --------------------------------------------------------

--
-- Table structure for table `payroll_runs`
--

DROP TABLE IF EXISTS `payroll_runs`;
CREATE TABLE `payroll_runs` (
  `PayrollRun_ID` int(11) NOT NULL,
  `PayrollPeriod_ID` int(11) NOT NULL,
  `Employee_ID` int(11) NOT NULL,
  `basic_pay` decimal(10,2) NOT NULL DEFAULT 18000.00,
  `overtime_pay` decimal(10,2) NOT NULL DEFAULT 0.00,
  `allowances_total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `deductions_total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `gross_pay` decimal(10,2) GENERATED ALWAYS AS (`basic_pay` + `overtime_pay` + `allowances_total`) STORED,
  `net_pay` decimal(10,2) GENERATED ALWAYS AS (`basic_pay` + `overtime_pay` + `allowances_total` - `deductions_total`) STORED,
  `generated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `generated_by` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payroll_runs`
--

INSERT INTO `payroll_runs` (`PayrollRun_ID`, `PayrollPeriod_ID`, `Employee_ID`, `basic_pay`, `overtime_pay`, `allowances_total`, `deductions_total`, `generated_at`, `generated_by`) VALUES
(1001, 1001, 1001, 45000.00, 5000.00, 7000.00, 2700.00, '2026-02-20 12:00:00', 1001),
(1002, 1001, 1002, 25000.00, 2000.00, 1000.00, 500.00, '2026-02-20 12:05:00', 1001),
(1003, 1001, 1003, 38000.00, 1500.00, 500.00, 800.00, '2026-02-20 12:10:00', 1001),
(1004, 1001, 1004, 42000.00, 1000.00, 700.00, 1000.00, '2026-02-20 12:15:00', 1002),
(1005, 1001, 1005, 50000.00, 0.00, 1500.00, 2000.00, '2026-02-20 12:20:00', 1001),
(1016, 1002, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1017, 1002, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1018, 1002, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1019, 1002, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1020, 1002, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1021, 1002, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1022, 1002, 1013, 200000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1023, 1002, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1024, 1002, 1015, 100000.00, 0.00, 0.00, 0.00, '2026-02-23 01:35:14', 1015),
(1025, 1003, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1026, 1003, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1027, 1003, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1028, 1003, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1029, 1003, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1030, 1003, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1031, 1003, 1013, 200000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1032, 1003, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-23 02:01:01', 1015),
(1033, 1003, 1015, 100000.00, 0.00, -1.00, 10000.00, '2026-02-23 02:01:01', 1015),
(1034, 1004, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1035, 1004, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1036, 1004, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1037, 1004, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1038, 1004, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1039, 1004, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:27', 1015),
(1040, 1004, 1013, 200000.00, 0.00, 0.00, 0.00, '2026-02-23 02:27:28', 1015),
(1041, 1004, 1014, 20000.00, 0.00, 1.00, 15000.00, '2026-02-23 02:27:28', 1015),
(1042, 1004, 1015, 100000.00, 0.00, 6500.00, 10000.00, '2026-02-23 02:27:28', 1015),
(1043, 1006, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1044, 1006, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1045, 1006, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1046, 1006, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1047, 1006, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1048, 1006, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1049, 1006, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1050, 1006, 1015, 100000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1051, 1006, 1018, 200000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1052, 1006, 1019, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:38:43', 1001),
(1053, 1007, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1054, 1007, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1055, 1007, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1056, 1007, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1057, 1007, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1058, 1007, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1059, 1007, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1060, 1007, 1015, 100000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1061, 1007, 1018, 200000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1062, 1007, 1019, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:42:05', 1001),
(1063, 1008, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1064, 1008, 1002, 25000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1065, 1008, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1066, 1008, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1067, 1008, 1005, 50000.00, 0.00, 0.00, 10000.00, '2026-02-24 00:59:32', 1001),
(1068, 1008, 1011, 28000.00, 0.00, 2000.00, 500.00, '2026-02-24 00:59:32', 1001),
(1069, 1008, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1070, 1008, 1015, 100000.00, 0.00, 10000.00, 15000.00, '2026-02-24 00:59:32', 1001),
(1071, 1008, 1018, 200000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1072, 1008, 1019, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 00:59:32', 1001),
(1073, 1009, 1002, 28000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1074, 1009, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1075, 1009, 1004, 42000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1076, 1009, 1005, 50000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1077, 1009, 1006, 35000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1078, 1009, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1079, 1009, 1012, 123123.00, 0.00, 50000.00, 10000.00, '2026-02-24 10:13:26', 1001),
(1080, 1009, 1013, 200000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1081, 1009, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1082, 1009, 1015, 100000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1083, 1009, 1018, 200000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1084, 1009, 1019, 20000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1085, 1009, 1024, 23222.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1086, 1009, 1025, 100000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1087, 1009, 1026, 65000.00, 0.00, 0.00, 0.00, '2026-02-24 10:13:26', 1001),
(1088, 1010, 1001, 45000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1089, 1010, 1002, 28000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1090, 1010, 1003, 38000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1091, 1010, 1006, 35000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1092, 1010, 1011, 28000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1093, 1010, 1012, 123123.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1094, 1010, 1013, 200000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1095, 1010, 1014, 20000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1096, 1010, 1015, 100000.00, 0.00, 10000.00, 500.00, '2026-02-25 20:49:42', 1001),
(1097, 1010, 1018, 200000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1098, 1010, 1019, 20000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1099, 1010, 1024, 23222.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1100, 1010, 1025, 100000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001),
(1101, 1010, 1026, 65000.00, 0.00, 0.00, 0.00, '2026-02-25 20:49:42', 1001);

-- --------------------------------------------------------

--
-- Table structure for table `payslips`
--

DROP TABLE IF EXISTS `payslips`;
CREATE TABLE `payslips` (
  `Payslip_ID` int(11) NOT NULL,
  `PayrollRun_ID` int(11) NOT NULL,
  `pdf_path` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payslips`
--

INSERT INTO `payslips` (`Payslip_ID`, `PayrollRun_ID`, `pdf_path`, `created_at`) VALUES
(1001, 1001, '/payslips/2026-02-shu_lli.pdf', '2026-02-16 22:44:35'),
(1002, 1002, '/payslips/2026-02-david_k.pdf', '2026-02-16 22:44:35'),
(1003, 1003, '/payslips/2026-02-emma_s.pdf', '2026-02-16 22:44:35'),
(1004, 1004, '/payslips/2026-02-frank99.pdf', '2026-02-16 22:44:35'),
(1005, 1005, '/payslips/2026-02-grace_h.pdf', '2026-02-16 22:44:35'),
(1006, 1016, NULL, '2026-02-23 01:58:26'),
(1007, 1017, NULL, '2026-02-23 01:58:26'),
(1008, 1018, NULL, '2026-02-23 01:58:26'),
(1009, 1019, NULL, '2026-02-23 01:58:26'),
(1010, 1020, NULL, '2026-02-23 01:58:26'),
(1011, 1021, NULL, '2026-02-23 01:58:26'),
(1012, 1022, NULL, '2026-02-23 01:58:26'),
(1013, 1023, NULL, '2026-02-23 01:58:26'),
(1014, 1024, NULL, '2026-02-23 01:58:26'),
(1021, 1025, NULL, '2026-02-23 02:01:01'),
(1022, 1026, NULL, '2026-02-23 02:01:01'),
(1023, 1027, NULL, '2026-02-23 02:01:01'),
(1024, 1028, NULL, '2026-02-23 02:01:01'),
(1025, 1029, NULL, '2026-02-23 02:01:01'),
(1026, 1030, NULL, '2026-02-23 02:01:01'),
(1027, 1031, NULL, '2026-02-23 02:01:01'),
(1028, 1032, NULL, '2026-02-23 02:01:01'),
(1029, 1033, NULL, '2026-02-23 02:01:01'),
(1036, 1034, NULL, '2026-02-23 02:27:28'),
(1037, 1035, NULL, '2026-02-23 02:27:28'),
(1038, 1036, NULL, '2026-02-23 02:27:28'),
(1039, 1037, NULL, '2026-02-23 02:27:28'),
(1040, 1038, NULL, '2026-02-23 02:27:28'),
(1041, 1039, NULL, '2026-02-23 02:27:28'),
(1042, 1040, NULL, '2026-02-23 02:27:28'),
(1043, 1041, NULL, '2026-02-23 02:27:28'),
(1044, 1042, NULL, '2026-02-23 02:27:28'),
(1045, 1043, NULL, '2026-02-24 00:38:43'),
(1046, 1044, NULL, '2026-02-24 00:38:43'),
(1047, 1045, NULL, '2026-02-24 00:38:43'),
(1048, 1046, NULL, '2026-02-24 00:38:43'),
(1049, 1047, NULL, '2026-02-24 00:38:43'),
(1050, 1048, NULL, '2026-02-24 00:38:43'),
(1051, 1049, NULL, '2026-02-24 00:38:43'),
(1052, 1050, NULL, '2026-02-24 00:38:43'),
(1053, 1051, NULL, '2026-02-24 00:38:43'),
(1054, 1052, NULL, '2026-02-24 00:38:43'),
(1060, 1053, NULL, '2026-02-24 00:42:05'),
(1061, 1054, NULL, '2026-02-24 00:42:05'),
(1062, 1055, NULL, '2026-02-24 00:42:05'),
(1063, 1056, NULL, '2026-02-24 00:42:05'),
(1064, 1057, NULL, '2026-02-24 00:42:05'),
(1065, 1058, NULL, '2026-02-24 00:42:05'),
(1066, 1059, NULL, '2026-02-24 00:42:05'),
(1067, 1060, NULL, '2026-02-24 00:42:05'),
(1068, 1061, NULL, '2026-02-24 00:42:05'),
(1069, 1062, NULL, '2026-02-24 00:42:05'),
(1075, 1063, NULL, '2026-02-24 00:59:32'),
(1076, 1064, NULL, '2026-02-24 00:59:32'),
(1077, 1065, NULL, '2026-02-24 00:59:32'),
(1078, 1066, NULL, '2026-02-24 00:59:32'),
(1079, 1067, NULL, '2026-02-24 00:59:32'),
(1080, 1068, NULL, '2026-02-24 00:59:32'),
(1081, 1069, NULL, '2026-02-24 00:59:32'),
(1082, 1070, NULL, '2026-02-24 00:59:32'),
(1083, 1071, NULL, '2026-02-24 00:59:32'),
(1084, 1072, NULL, '2026-02-24 00:59:32'),
(1085, 1073, NULL, '2026-02-24 10:13:26'),
(1086, 1074, NULL, '2026-02-24 10:13:26'),
(1087, 1075, NULL, '2026-02-24 10:13:26'),
(1088, 1076, NULL, '2026-02-24 10:13:26'),
(1089, 1077, NULL, '2026-02-24 10:13:26'),
(1090, 1078, NULL, '2026-02-24 10:13:26'),
(1091, 1079, NULL, '2026-02-24 10:13:26'),
(1092, 1080, NULL, '2026-02-24 10:13:26'),
(1093, 1081, NULL, '2026-02-24 10:13:26'),
(1094, 1082, NULL, '2026-02-24 10:13:26'),
(1095, 1083, NULL, '2026-02-24 10:13:26'),
(1096, 1084, NULL, '2026-02-24 10:13:26'),
(1097, 1085, NULL, '2026-02-24 10:13:26'),
(1098, 1086, NULL, '2026-02-24 10:13:26'),
(1099, 1087, NULL, '2026-02-24 10:13:26'),
(1100, 1088, NULL, '2026-02-25 20:49:43'),
(1101, 1089, NULL, '2026-02-25 20:49:43'),
(1102, 1090, NULL, '2026-02-25 20:49:43'),
(1103, 1091, NULL, '2026-02-25 20:49:43'),
(1104, 1092, NULL, '2026-02-25 20:49:43'),
(1105, 1093, NULL, '2026-02-25 20:49:43'),
(1106, 1094, NULL, '2026-02-25 20:49:43'),
(1107, 1095, NULL, '2026-02-25 20:49:43'),
(1108, 1096, NULL, '2026-02-25 20:49:43'),
(1109, 1097, NULL, '2026-02-25 20:49:43'),
(1110, 1098, NULL, '2026-02-25 20:49:43'),
(1111, 1099, NULL, '2026-02-25 20:49:43'),
(1112, 1100, NULL, '2026-02-25 20:49:43'),
(1113, 1101, NULL, '2026-02-25 20:49:43');

-- --------------------------------------------------------

--
-- Table structure for table `positions`
--

DROP TABLE IF EXISTS `positions`;
CREATE TABLE `positions` (
  `Position_ID` int(11) NOT NULL,
  `Department_ID` int(11) NOT NULL,
  `title` varchar(80) NOT NULL,
  `default_base_salary` decimal(10,2) NOT NULL DEFAULT 18000.00
) ;

--
-- Dumping data for table `positions`
--

INSERT INTO `positions` (`Position_ID`, `Department_ID`, `title`, `default_base_salary`) VALUES
(1001, 1001, 'Art Director', 45000.00),
(1002, 1001, 'Graphic Designer', 25000.00),
(1003, 1001, 'Video Editor', 30000.00),
(1004, 1001, 'Copywriter', 28000.00),
(1005, 1002, 'Social Media Manager', 35000.00),
(1006, 1002, 'Content Strategist', 38000.00),
(1007, 1002, 'Community Manager', 22000.00),
(1008, 1003, 'Account Executive', 26000.00),
(1009, 1003, 'Account Manager', 42000.00),
(1010, 1003, 'Client Success Specialist', 30000.00),
(1011, 1004, 'Web Developer', 40000.00),
(1012, 1004, 'IT Support Specialist', 24000.00),
(1013, 1004, 'Operations Manager', 50000.00);

-- --------------------------------------------------------

--
-- Table structure for table `shifts`
--

DROP TABLE IF EXISTS `shifts`;
CREATE TABLE `shifts` (
  `Shift_ID` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `time_start` time NOT NULL,
  `time_end` time NOT NULL,
  `break_minutes` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `shifts`
--

INSERT INTO `shifts` (`Shift_ID`, `name`, `time_start`, `time_end`, `break_minutes`) VALUES
(1001, 'Day', '09:00:00', '17:00:00', 60),
(1002, 'Afternoon', '13:00:00', '21:00:00', 60),
(1003, 'Night', '21:00:00', '05:00:00', 45);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `User_ID` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `email` varchar(120) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','manager','employee') NOT NULL DEFAULT 'employee',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`User_ID`, `username`, `email`, `password_hash`, `role`, `is_active`, `created_at`) VALUES
(1001, 'shu_lli', 'shulli@jsoncorp.com', '$2b$10$u26YFBIoHbdPyHEJn96.EuaaehXVIEpQ7/lk8.ywXLD.f5lZJ5Cre', 'admin', 1, '2026-02-16 21:36:24'),
(1002, 'david_santos_new', 'david.old@jsoncorp.com', '$2b$10$lcnjYTHgKA4sK8dhI5ZB1OOH0nbgK.4RBHa4opTD/kksuw29UA2TO', 'employee', 1, '2026-02-16 21:36:24'),
(1003, 'emma_s', 'emma_s@jsoncorp.com', '$2b$10$G.WUOsvgKc0ZRpmzwHyEpOshM6MXHFnEO3orr4qjeu9rhkLfLgIdi', 'employee', 1, '2026-02-16 21:36:24'),
(1004, 'frank101', 'frank101@jsoncorp.com', '$2b$10$As69P3VSuk.nBAQWDd6Piu2nFUigwDVehhsMC7Ficdwe6FcNp2cnq', 'employee', 1, '2026-02-16 21:36:24'),
(1005, 'grace_h', 'grace.h@jsoncorp.com', '$2b$10$jQnAlt5bCj2XEegVZaMw/eV7RBhI4BLOOzDd7rOgIyp3iTgG7Lw2.', 'employee', 1, '2026-02-16 21:36:24'),
(1007, 'sam_j', 'sam@jsoncorp.com', '$2y$10$DUl7fWJTKfuixCw3yRJzbu/no4mudUxJ7RZSojIsyOo5LRAp.1blG', 'employee', 1, '2026-02-17 19:59:26'),
(1043, 'jdoe_2026', 'j.doe@jsoncorp.com', '$2y$10$92DuLPnYS.M4Jhb8e7T0YOI8jCcbk6EVaNBpRtysf94QlTLKlTG4y', 'employee', 1, '2026-02-22 04:27:43'),
(1044, 'hulk_b', 'banner@jsoncorp.com', '$2y$10$SMSnbwj0NIIGZ/ESTfNpeuDGKfqYIy/wVwnmCBbncxnvQiL1GGGTu', 'employee', 0, '2026-02-22 04:28:32'),
(1045, 'nat_r', 'blackwidow@jsoncorp.com', '$2y$10$NVEw1EH67uHVUb79Y8Sh.ep/R9o5uO7FvgBhFPEQ9.WabPOKKy9D6', 'admin', 1, '2026-02-22 16:55:03'),
(1046, 'Ethan18', 'eefrancisco@company.com', '$2y$10$Ly9XHfVxqWRt/uI9SYBTJ.XGPumHGxHnYA1FqxVDk7Q.HW74ARUSa', 'employee', 1, '2026-02-22 23:24:42'),
(1049, 'Zeit', 'zeit@company.com', '$2y$10$4H.9m7e/c.79uIKn74EUIO2iboB15.V8BFO9XsoWXXnAmNzBIfjR2', 'admin', 1, '2026-02-22 23:46:03'),
(1051, 'tony_stark', 'ironman@jsoncorp.com', '$2y$10$Sp1xGzERySC9G1EcE7KK7.J6P5FZhId3P9fAuvRNBBXEf9U0jgY1S', 'admin', 0, '2026-02-23 17:23:17'),
(1053, 'cap_rogers', 'stever@jsoncorp.com', '$2y$10$HQ2w3WiRacGWeLuycm84XuUMWomCZcd1M1XoZGQpejt1gLMINzTiW', 'employee', 0, '2026-02-23 17:48:30'),
(1056, 'Walter', 'mexico@gmail.com', '$2y$10$Tk5a4J4PUkX5qM5GthbNY.n/N61IbPcv/o5e1f4gfUb4wcIFqWBhm', 'employee', 1, '2026-02-23 18:18:36'),
(1057, 'JaneDoe', 'janedoe@company.com', '$2y$10$7st3KVnIP4XIYqdNB6SHqe/ODDHph24J/v.le2XxSSujvVcKtSd/m', 'employee', 1, '2026-02-23 22:48:35'),
(1062, 'm_smith02', 'mary.smith@example.com', '$2y$10$3TE1LjuuFeS/bvZPODYLC.cL1NE.cgj7gkzwr7MfH0cGot3x8KFKq', 'employee', 1, '2026-02-24 03:45:07'),
(1063, 'ethan_james', 'ejames@jsoncorp.com', '$2y$10$Anr1NiDaKcAAvo01wJ9LZeMGYgVoi74zZTHuCHNqr2I/eruY1Go0C', 'employee', 1, '2026-02-24 03:54:06'),
(1065, 'clark_kent', 'ckent@dailyplanet.com', '$2y$10$evGqPsaHd.Fe1Jz1U/zFFe5jrg9aPCAhposqTxZcKROmMO7RU5TEm', 'employee', 1, '2026-02-24 10:07:25'),
(1069, 'testEmployee', 'testEmployee@company.com', '$2y$10$EhFM8vxUYXikWrXt4eiLIuwi4p05TtycrQ/DlK3vPKiBoSmM6HJ6G', 'employee', 0, '2026-02-25 20:45:58');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `attendance`
--
ALTER TABLE `attendance`
  ADD PRIMARY KEY (`Attendance_ID`),
  ADD UNIQUE KEY `uniq_attendance_per_day` (`Employee_ID`,`attendance_date`),
  ADD UNIQUE KEY `Employee_ID` (`Employee_ID`,`attendance_date`);

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`Department_ID`),
  ADD UNIQUE KEY `name` (`name`),
  ADD KEY `fk_departments_manager` (`department_manager_id`);

--
-- Indexes for table `employees`
--
ALTER TABLE `employees`
  ADD PRIMARY KEY (`Employee_ID`),
  ADD UNIQUE KEY `User_ID` (`User_ID`),
  ADD KEY `Department_ID` (`Department_ID`),
  ADD KEY `Position_ID` (`Position_ID`);

--
-- Indexes for table `employee_edit_logs`
--
ALTER TABLE `employee_edit_logs`
  ADD PRIMARY KEY (`Log_ID`),
  ADD KEY `Employee_ID` (`Employee_ID`),
  ADD KEY `changed_by` (`changed_by`);

--
-- Indexes for table `employee_shifts`
--
ALTER TABLE `employee_shifts`
  ADD PRIMARY KEY (`EmployShift_ID`),
  ADD UNIQUE KEY `Employee_ID_2` (`Employee_ID`),
  ADD KEY `Employee_ID` (`Employee_ID`),
  ADD KEY `Shift_ID` (`Shift_ID`);

--
-- Indexes for table `leave_balances`
--
ALTER TABLE `leave_balances`
  ADD PRIMARY KEY (`LeaveBal_ID`),
  ADD UNIQUE KEY `uniq_leave_balance` (`Employee_ID`,`LeaveType_ID`,`year`),
  ADD KEY `LeaveType_ID` (`LeaveType_ID`);

--
-- Indexes for table `leave_requests`
--
ALTER TABLE `leave_requests`
  ADD PRIMARY KEY (`LeaveReq_ID`),
  ADD KEY `Employee_ID` (`Employee_ID`),
  ADD KEY `leave_type_id` (`leave_type_id`),
  ADD KEY `reviewed_by` (`reviewed_by`);

--
-- Indexes for table `leave_types`
--
ALTER TABLE `leave_types`
  ADD PRIMARY KEY (`LeaveType_ID`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `payroll_adjustments`
--
ALTER TABLE `payroll_adjustments`
  ADD PRIMARY KEY (`adjustment_id`),
  ADD KEY `payroll_run_id` (`payroll_run_id`);

--
-- Indexes for table `payroll_allowances`
--
ALTER TABLE `payroll_allowances`
  ADD PRIMARY KEY (`PayrollAllowance_ID`),
  ADD KEY `PayrollRun_ID` (`PayrollRun_ID`);

--
-- Indexes for table `payroll_deductions`
--
ALTER TABLE `payroll_deductions`
  ADD PRIMARY KEY (`PayrollDeduction_ID`),
  ADD KEY `PayrollRun_ID` (`PayrollRun_ID`);

--
-- Indexes for table `payroll_periods`
--
ALTER TABLE `payroll_periods`
  ADD PRIMARY KEY (`PayrollPeriod_ID`),
  ADD UNIQUE KEY `uniq_period` (`period_start`,`period_end`);

--
-- Indexes for table `payroll_runs`
--
ALTER TABLE `payroll_runs`
  ADD PRIMARY KEY (`PayrollRun_ID`),
  ADD UNIQUE KEY `uniq_payroll_per_period` (`PayrollPeriod_ID`,`Employee_ID`),
  ADD KEY `Employee_ID` (`Employee_ID`),
  ADD KEY `generated_by` (`generated_by`);

--
-- Indexes for table `payslips`
--
ALTER TABLE `payslips`
  ADD PRIMARY KEY (`Payslip_ID`),
  ADD UNIQUE KEY `PayrollRun_ID` (`PayrollRun_ID`);

--
-- Indexes for table `positions`
--
ALTER TABLE `positions`
  ADD PRIMARY KEY (`Position_ID`),
  ADD KEY `Department_ID` (`Department_ID`);

--
-- Indexes for table `shifts`
--
ALTER TABLE `shifts`
  ADD PRIMARY KEY (`Shift_ID`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`User_ID`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `attendance`
--
ALTER TABLE `attendance`
  MODIFY `Attendance_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1009;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `Department_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1005;

--
-- AUTO_INCREMENT for table `employees`
--
ALTER TABLE `employees`
  MODIFY `Employee_ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `employee_edit_logs`
--
ALTER TABLE `employee_edit_logs`
  MODIFY `Log_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `employee_shifts`
--
ALTER TABLE `employee_shifts`
  MODIFY `EmployShift_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1057;

--
-- AUTO_INCREMENT for table `leave_balances`
--
ALTER TABLE `leave_balances`
  MODIFY `LeaveBal_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `leave_requests`
--
ALTER TABLE `leave_requests`
  MODIFY `LeaveReq_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `leave_types`
--
ALTER TABLE `leave_types`
  MODIFY `LeaveType_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `payroll_adjustments`
--
ALTER TABLE `payroll_adjustments`
  MODIFY `adjustment_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payroll_allowances`
--
ALTER TABLE `payroll_allowances`
  MODIFY `PayrollAllowance_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1016;

--
-- AUTO_INCREMENT for table `payroll_deductions`
--
ALTER TABLE `payroll_deductions`
  MODIFY `PayrollDeduction_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1016;

--
-- AUTO_INCREMENT for table `payroll_periods`
--
ALTER TABLE `payroll_periods`
  MODIFY `PayrollPeriod_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1011;

--
-- AUTO_INCREMENT for table `payroll_runs`
--
ALTER TABLE `payroll_runs`
  MODIFY `PayrollRun_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1102;

--
-- AUTO_INCREMENT for table `payslips`
--
ALTER TABLE `payslips`
  MODIFY `Payslip_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1115;

--
-- AUTO_INCREMENT for table `positions`
--
ALTER TABLE `positions`
  MODIFY `Position_ID` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `shifts`
--
ALTER TABLE `shifts`
  MODIFY `Shift_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1004;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `User_ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1070;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendance`
--
ALTER TABLE `attendance`
  ADD CONSTRAINT `attendance_ibfk_1` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `departments`
--
ALTER TABLE `departments`
  ADD CONSTRAINT `fk_departments_manager` FOREIGN KEY (`department_manager_id`) REFERENCES `employees` (`Employee_ID`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `employees`
--
ALTER TABLE `employees`
  ADD CONSTRAINT `employees_ibfk_1` FOREIGN KEY (`User_ID`) REFERENCES `users` (`User_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `employees_ibfk_3` FOREIGN KEY (`Department_ID`) REFERENCES `departments` (`Department_ID`) ON UPDATE CASCADE,
  ADD CONSTRAINT `employees_ibfk_4` FOREIGN KEY (`Position_ID`) REFERENCES `positions` (`Position_ID`) ON UPDATE CASCADE;

--
-- Constraints for table `employee_edit_logs`
--
ALTER TABLE `employee_edit_logs`
  ADD CONSTRAINT `employee_edit_logs_ibfk_1` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `employee_edit_logs_ibfk_2` FOREIGN KEY (`changed_by`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `employee_shifts`
--
ALTER TABLE `employee_shifts`
  ADD CONSTRAINT `employee_shifts_ibfk_1` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `employee_shifts_ibfk_2` FOREIGN KEY (`Shift_ID`) REFERENCES `shifts` (`Shift_ID`) ON UPDATE CASCADE;

--
-- Constraints for table `leave_balances`
--
ALTER TABLE `leave_balances`
  ADD CONSTRAINT `leave_balances_ibfk_1` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `leave_balances_ibfk_2` FOREIGN KEY (`LeaveType_ID`) REFERENCES `leave_types` (`LeaveType_ID`) ON UPDATE CASCADE;

--
-- Constraints for table `leave_requests`
--
ALTER TABLE `leave_requests`
  ADD CONSTRAINT `leave_requests_ibfk_1` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `leave_requests_ibfk_2` FOREIGN KEY (`leave_type_id`) REFERENCES `leave_types` (`LeaveType_ID`) ON UPDATE CASCADE,
  ADD CONSTRAINT `leave_requests_ibfk_3` FOREIGN KEY (`reviewed_by`) REFERENCES `employees` (`Employee_ID`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `payroll_adjustments`
--
ALTER TABLE `payroll_adjustments`
  ADD CONSTRAINT `payroll_adjustments_ibfk_1` FOREIGN KEY (`payroll_run_id`) REFERENCES `payroll_runs` (`PayrollRun_ID`) ON DELETE CASCADE;

--
-- Constraints for table `payroll_allowances`
--
ALTER TABLE `payroll_allowances`
  ADD CONSTRAINT `payroll_allowances_ibfk_1` FOREIGN KEY (`PayrollRun_ID`) REFERENCES `payroll_runs` (`PayrollRun_ID`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `payroll_deductions`
--
ALTER TABLE `payroll_deductions`
  ADD CONSTRAINT `payroll_deductions_ibfk_1` FOREIGN KEY (`PayrollRun_ID`) REFERENCES `payroll_runs` (`PayrollRun_ID`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `payroll_runs`
--
ALTER TABLE `payroll_runs`
  ADD CONSTRAINT `payroll_runs_ibfk_1` FOREIGN KEY (`PayrollPeriod_ID`) REFERENCES `payroll_periods` (`PayrollPeriod_ID`) ON UPDATE CASCADE,
  ADD CONSTRAINT `payroll_runs_ibfk_2` FOREIGN KEY (`Employee_ID`) REFERENCES `employees` (`Employee_ID`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `payroll_runs_ibfk_3` FOREIGN KEY (`generated_by`) REFERENCES `employees` (`Employee_ID`) ON UPDATE CASCADE;

--
-- Constraints for table `payslips`
--
ALTER TABLE `payslips`
  ADD CONSTRAINT `payslips_ibfk_1` FOREIGN KEY (`PayrollRun_ID`) REFERENCES `payroll_runs` (`PayrollRun_ID`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `positions`
--
ALTER TABLE `positions`
  ADD CONSTRAINT `positions_ibfk_1` FOREIGN KEY (`Department_ID`) REFERENCES `departments` (`Department_ID`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

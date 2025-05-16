-- 예시 회원 데이터 생성 스크립트 (init-data.sql)
CREATE DATABASE IF NOT EXISTS userdb;
USE userdb;

-- 사용자 테이블
CREATE TABLE users (
                       id INT PRIMARY KEY AUTO_INCREMENT,
                       email VARCHAR(255) UNIQUE NOT NULL,
                       password_hash VARCHAR(255) NOT NULL,
                       first_name VARCHAR(100),
                       last_name VARCHAR(100),
                       phone VARCHAR(20),
                       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                       updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 사용자 프로필 테이블
CREATE TABLE user_profiles (
                               id INT PRIMARY KEY AUTO_INCREMENT,
                               user_id INT,
                               birth_date DATE,
                               gender ENUM('M', 'F', 'Other'),
                               address TEXT,
                               FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 분석 결과 테이블
CREATE TABLE analysis_results (
                                  id INT PRIMARY KEY AUTO_INCREMENT,
                                  user_id INT,
                                  test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                  sperm_count INT,
                                  motility_percentage DECIMAL(5,2),
                                  morphology_score INT,
                                  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 10만명 사용자 데이터 생성 프로시저
DELIMITER //
CREATE PROCEDURE GenerateUsers()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 100000 DO
        INSERT INTO users (email, password_hash, first_name, last_name, phone)
        VALUES (
            CONCAT('user', i, '@example.com'),
            SHA2(CONCAT('password', i), 256),
            CONCAT('FirstName', i),
            CONCAT('LastName', i),
            CONCAT('010-', FLOOR(1000 + RAND() * 9000), '-', FLOOR(1000 + RAND() * 9000))
        );

INSERT INTO user_profiles (user_id, birth_date, gender, address)
VALUES (
           i,
           DATE_SUB(CURDATE(), INTERVAL FLOOR(20 + RAND() * 50) YEAR),
           CASE FLOOR(RAND() * 3) WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'Other' END,
           CONCAT('Address ', i, ', Seoul, Korea')
       );

INSERT INTO analysis_results (user_id, sperm_count, motility_percentage, morphology_score)
VALUES (
           i,
           FLOOR(15000000 + RAND() * 300000000),
           ROUND(30 + RAND() * 70, 2),
           FLOOR(4 + RAND() * 11)
       );

SET i = i + 1;
END WHILE;
END //
DELIMITER ;

-- 프로시저 실행
CALL GenerateUsers();

-- 생성된 데이터 확인
SELECT 'Data generation completed' as status;
SELECT 'Users:', COUNT(*) FROM users;
SELECT 'User Profiles:', COUNT(*) FROM user_profiles;
SELECT 'Analysis Results:', COUNT(*) FROM analysis_results;

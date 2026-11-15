-- Başlangıç şeması. Tüm tarih-saatler Türkiye yerel saatiyle (Europe/Istanbul) tutulur.
-- Zaman değerleri uygulamadan gönderilir; SQL içinde NOW() kullanılmaz.

CREATE TABLE users (
    id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    role                  ENUM('super_admin','institution_admin','doctor','patient') NOT NULL,
    first_name            VARCHAR(100) NOT NULL,
    last_name             VARCHAR(100) NOT NULL,
    email                 VARCHAR(255) NOT NULL,
    phone                 VARCHAR(20)  NULL,
    password_hash         VARCHAR(255) NOT NULL,
    must_change_password  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at            DATETIME     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE patients (
    user_id      BIGINT UNSIGNED NOT NULL,
    national_id  CHAR(11) NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_patients_national_id (national_id),
    CONSTRAINT fk_patients_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT chk_patients_national_id CHECK (national_id REGEXP '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE institutions (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(200) NOT NULL,
    type        ENUM('hospital','clinic') NOT NULL,
    address     VARCHAR(500) NOT NULL,
    phone       VARCHAR(20)  NOT NULL,
    email       VARCHAR(255) NOT NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE institution_applications (
    id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    institution_name      VARCHAR(200) NOT NULL,
    institution_type      ENUM('hospital','clinic') NOT NULL,
    institution_address   VARCHAR(500) NOT NULL,
    institution_phone     VARCHAR(20)  NOT NULL,
    institution_email     VARCHAR(255) NOT NULL,
    admin_first_name      VARCHAR(100) NOT NULL,
    admin_last_name       VARCHAR(100) NOT NULL,
    admin_email           VARCHAR(255) NOT NULL,
    admin_phone           VARCHAR(20)  NOT NULL,
    admin_password_hash   VARCHAR(255) NOT NULL,
    status                ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    institution_id        BIGINT UNSIGNED NULL,
    created_at            DATETIME NOT NULL,
    decided_at            DATETIME NULL,
    PRIMARY KEY (id),
    KEY ix_applications_admin_email (admin_email),
    KEY ix_applications_status (status),
    CONSTRAINT fk_applications_institution FOREIGN KEY (institution_id) REFERENCES institutions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE institution_admins (
    user_id         BIGINT UNSIGNED NOT NULL,
    institution_id  BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id),
    KEY ix_institution_admins_institution (institution_id),
    CONSTRAINT fk_institution_admins_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_institution_admins_institution FOREIGN KEY (institution_id) REFERENCES institutions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE branches (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    institution_id  BIGINT UNSIGNED NOT NULL,
    name            VARCHAR(200) NOT NULL,
    address         VARCHAR(500) NULL,
    phone           VARCHAR(20)  NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_branches_institution_name (institution_id, name),
    CONSTRAINT fk_branches_institution FOREIGN KEY (institution_id) REFERENCES institutions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

-- weekday: 1 = Pazartesi ... 7 = Pazar. Şube başına günde tek açılış-kapanış aralığı.
CREATE TABLE working_hours (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    branch_id  BIGINT UNSIGNED NOT NULL,
    weekday    TINYINT UNSIGNED NOT NULL,
    opens_at   TIME NOT NULL,
    closes_at  TIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_working_hours_branch_weekday (branch_id, weekday),
    CONSTRAINT fk_working_hours_branch FOREIGN KEY (branch_id) REFERENCES branches (id),
    CONSTRAINT chk_working_hours_weekday CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT chk_working_hours_range CHECK (closes_at > opens_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE departments (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    branch_id  BIGINT UNSIGNED NOT NULL,
    name       VARCHAR(200) NOT NULL,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_departments_branch_name (branch_id, name),
    CONSTRAINT fk_departments_branch FOREIGN KEY (branch_id) REFERENCES branches (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE services (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    department_id  BIGINT UNSIGNED NOT NULL,
    name           VARCHAR(200) NOT NULL,
    duration_min   SMALLINT UNSIGNED NOT NULL,
    price          DECIMAL(10,2) NOT NULL,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_services_department_name (department_id, name),
    CONSTRAINT fk_services_department FOREIGN KEY (department_id) REFERENCES departments (id),
    CONSTRAINT chk_services_duration CHECK (duration_min > 0 AND duration_min <= 480),
    CONSTRAINT chk_services_price CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

-- Doktor tek şubede ve tek bölümde çalışır. Bölümün şubesi ile branch_id uyumu uygulamada denetlenir.
CREATE TABLE doctors (
    user_id        BIGINT UNSIGNED NOT NULL,
    branch_id      BIGINT UNSIGNED NOT NULL,
    department_id  BIGINT UNSIGNED NOT NULL,
    specialty      VARCHAR(200) NOT NULL DEFAULT '',
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (user_id),
    KEY ix_doctors_branch (branch_id),
    KEY ix_doctors_department (department_id),
    CONSTRAINT fk_doctors_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_doctors_branch FOREIGN KEY (branch_id) REFERENCES branches (id),
    CONSTRAINT fk_doctors_department FOREIGN KEY (department_id) REFERENCES departments (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE doctor_services (
    doctor_id   BIGINT UNSIGNED NOT NULL,
    service_id  BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (doctor_id, service_id),
    KEY ix_doctor_services_service (service_id),
    CONSTRAINT fk_doctor_services_doctor FOREIGN KEY (doctor_id) REFERENCES doctors (user_id),
    CONSTRAINT fk_doctor_services_service FOREIGN KEY (service_id) REFERENCES services (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

-- Doktorun haftalık uygunluk dilimleri. Öğle arasını kapsayabilir; 12:00-13:00 slot üretiminde kesilir.
CREATE TABLE availabilities (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    doctor_id   BIGINT UNSIGNED NOT NULL,
    weekday     TINYINT UNSIGNED NOT NULL,
    start_time  TIME NOT NULL,
    end_time    TIME NOT NULL,
    PRIMARY KEY (id),
    KEY ix_availabilities_doctor_weekday (doctor_id, weekday),
    CONSTRAINT fk_availabilities_doctor FOREIGN KEY (doctor_id) REFERENCES doctors (user_id),
    CONSTRAINT chk_availabilities_weekday CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT chk_availabilities_range CHECK (end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

-- Hizmet adı, süre ve ücret randevu anındaki değerleriyle kopyalanır.
CREATE TABLE appointments (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    patient_id    BIGINT UNSIGNED NOT NULL,
    doctor_id     BIGINT UNSIGNED NOT NULL,
    service_id    BIGINT UNSIGNED NOT NULL,
    start_at      DATETIME NOT NULL,
    end_at        DATETIME NOT NULL,
    status        ENUM('pending','approved','rejected','cancelled','completed') NOT NULL DEFAULT 'pending',
    service_name  VARCHAR(200) NOT NULL,
    duration_min  SMALLINT UNSIGNED NOT NULL,
    price         DECIMAL(10,2) NOT NULL,
    cancelled_by  ENUM('patient','doctor','admin','system') NULL,
    cancelled_at  DATETIME NULL,
    created_at    DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY ix_appointments_doctor_start (doctor_id, start_at),
    KEY ix_appointments_patient_start (patient_id, start_at),
    KEY ix_appointments_status_start (status, start_at),
    CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id) REFERENCES patients (user_id),
    CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id) REFERENCES doctors (user_id),
    CONSTRAINT fk_appointments_service FOREIGN KEY (service_id) REFERENCES services (id),
    CONSTRAINT chk_appointments_range CHECK (end_at > start_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE notifications (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id         BIGINT UNSIGNED NOT NULL,
    appointment_id  BIGINT UNSIGNED NOT NULL,
    type            ENUM('appointment_approved','appointment_rejected','appointment_cancelled_by_doctor','appointment_cancelled_by_admin','appointment_cancelled_auto') NOT NULL,
    message         VARCHAR(500) NOT NULL,
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY ix_notifications_user (user_id, is_read, created_at),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_notifications_appointment FOREIGN KEY (appointment_id) REFERENCES appointments (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

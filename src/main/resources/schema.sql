CREATE TABLE `mail_log`
(
    `m_log_id`       INT         NOT NULL AUTO_INCREMENT,
    `frst_send_date` DATETIME NULL,
    `lst_send_date`  DATETIME NULL,
    `try_count`      INT         NOT NULL DEFAULT 0,
    `send_state`     VARCHAR(10) NOT NULL DEFAULT 'WAITING' COMMENT 'WAITING/FAILED/SUCCEEDED',
    `cond_id`        INT         NOT NULL,
    PRIMARY KEY (`m_log_id`)
);

CREATE TABLE `matching_log`
(
    `cond_id`   INT         NOT NULL,
    `atc_id`    VARCHAR(20) NOT NULL,
    `mtch_date` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `m_log_id`  INT NULL,
    PRIMARY KEY (`cond_id`, `atc_id`)
);

CREATE TABLE `mail_verification`
(
    `ver_id`         INT          NOT NULL AUTO_INCREMENT,
    `m_addr`         VARCHAR(255) NOT NULL,
    `ver_num`        VARCHAR(6)   NOT NULL,
    `ver_token`      VARCHAR(36) NULL	COMMENT '인증번호 확인 성공 시 발급하는 UUID. 확인 전에는 NULL',
    `token_exp_date` DATETIME NULL	COMMENT '토큰 발급 후 30분',
    `crt_date`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `exp_date`       DATETIME     NOT NULL,
    `wrng_count`     INT          NOT NULL DEFAULT 0,
    `is_used`        BOOLEAN      NOT NULL DEFAULT 0,
    PRIMARY KEY (`ver_id`)
);

CREATE TABLE `alert_condition`
(
    `cond_id`      INT          NOT NULL AUTO_INCREMENT,
    `m_addr`       VARCHAR(255) NOT NULL,
    `token`        VARCHAR(64)  NOT NULL COMMENT '무작위 값',
    `cond_st_nm`   VARCHAR(200) NULL	COMMENT 'found_item.st_nm과 비교하며 검색 물품과 둘 중 하나는 필수',
    `cond_prdt_nm` VARCHAR(200) NULL	COMMENT 'found_item.fd_prdt_nm과 띄어쓰기·영문 대소문자를 무시한 부분 일치로 비교',
    `exp_date`     DATETIME     NOT NULL COMMENT '등록 후 31일이며 도달 시 관련 기록 삭제',
    PRIMARY KEY (`cond_id`)
);

CREATE TABLE `found_item`
(
    `atc_id`           VARCHAR(20)  NOT NULL,
    `fd_sn`            INT          NOT NULL,
    `fd_prdt_nm`       VARCHAR(200) NOT NULL,
    `prdt_cl_nm`       VARCHAR(100) NULL,
    `clr_nm`           VARCHAR(100) NULL,
    `fd_ymd`           DATE         NOT NULL,
    `fd_hor`           VARCHAR(10) NULL,
    `fd_place`         VARCHAR(100) NULL,
    `dep_place`        VARCHAR(100) NOT NULL,
    `fd_file_path_img` VARCHAR(500) NULL,
    `cste_ste_nm`      VARCHAR(100) NOT NULL,
    `org_nm`           VARCHAR(400) NULL,
    `tel`              VARCHAR(15) NULL,
    `uniq`             TEXT NULL,
    `st_nm`            VARCHAR(200) NOT NULL COMMENT 'dep_place에서 역명만 순수하게 추출 (역사 내에 있는 유실물센터도 역으로 포함)',
    `frst_coll_date`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '알림 매칭 대상(신규 습득물) 판단 기준',
    `lst_ck_date`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '새벽 배치에서 보관 상태를 마지막으로 확인한 시각 (습득 후 7일까지 갱신)',
    `cls_ck_date`      DATETIME NULL	COMMENT '종결을 처음 확인한 시각이며 보관중이면 NULL',
    PRIMARY KEY (`atc_id`)
);

ALTER TABLE `mail_log`
    ADD CONSTRAINT `FK_alert_condition_TO_mail_log_1` FOREIGN KEY (
                                                                   `cond_id`
        )
        REFERENCES `alert_condition` (
                                      `cond_id`
            )
        ON DELETE CASCADE;

ALTER TABLE `matching_log`
    ADD CONSTRAINT `FK_alert_condition_TO_matching_log_1` FOREIGN KEY (
                                                                       `cond_id`
        )
        REFERENCES `alert_condition` (
                                      `cond_id`
            )
        ON DELETE CASCADE;

ALTER TABLE `matching_log`
    ADD CONSTRAINT `FK_found_item_TO_matching_log_1` FOREIGN KEY (
                                                                  `atc_id`
        )
        REFERENCES `found_item` (
                                 `atc_id`
            )
        ON DELETE CASCADE;

ALTER TABLE `matching_log`
    ADD CONSTRAINT `FK_mail_log_TO_matching_log_1` FOREIGN KEY (
                                                                `m_log_id`
        )
        REFERENCES `mail_log` (
                               `m_log_id`
            )
        ON DELETE CASCADE;

ALTER TABLE `mail_verification`
    ADD CONSTRAINT `UK_mail_verification_ver_token` UNIQUE (`ver_token`);

ALTER TABLE `alert_condition`
    ADD CONSTRAINT `UK_alert_condition_token` UNIQUE (`token`);
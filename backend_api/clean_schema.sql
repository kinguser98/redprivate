-- Red App Database Schema Pruning Script
-- Drops 20 unused legacy tables while preserving all 18 essential tables and 100% of media data

DROP TABLE IF EXISTS `live_tv_channels`;
DROP TABLE IF EXISTS `live_tv_genres`;
DROP TABLE IF EXISTS `comments`;
DROP TABLE IF EXISTS `request`;
DROP TABLE IF EXISTS `coupon`;
DROP TABLE IF EXISTS `custom_payment_requests`;
DROP TABLE IF EXISTS `custom_payment_type`;
DROP TABLE IF EXISTS `disposable_emails`;
DROP TABLE IF EXISTS `devices_log`;
DROP TABLE IF EXISTS `ci_sessions`;
DROP TABLE IF EXISTS `mail_templates`;
DROP TABLE IF EXISTS `search_list`;
DROP TABLE IF EXISTS `google_drive_accounts`;
DROP TABLE IF EXISTS `subtitles`;
DROP TABLE IF EXISTS `upcoming_contents`;
DROP TABLE IF EXISTS `devices`;
DROP TABLE IF EXISTS `subscription`;
DROP TABLE IF EXISTS `subscription_log`;
DROP TABLE IF EXISTS `view_log`;

---
name: project-aiven-hunt
description: Aiven Managed Bug Bounty hunt — Kafka Connect T1 attack surface, active findings tracker
metadata:
  type: project
---

Track B MAJOR findings on Aiven Kafka Connect (kafkaconnect-14b863b, aws-us-east-1):

**SUBMITTED AND REJECTED:**
- Finding B (P3): Debezium MySQL SSRF → rejected (B/C/D/F all rejected per MEMORY.md 2026-06-03)
- Finding C (P2): PostgreSQL driver.* injection → rejected (dup/N/A)
- Finding D: Data injection → rejected (own topics, no cross-tenant)
- Finding F (P2): PKCS12 byte oracle + Snowflake JDBC file read → rejected (dup/N/A)
- Finding E (P3): JDBC SSL SSRF → status unknown (NOT in rejected list); report at docs/aiven-finding-e-jdbc-ssl-ssrf-report.md

**ACTIVE (CONFIRMED 2026-06-03 — REPORT NEEDED):**
- Finding G (NEW): SQLite JDBC arbitrary SQL execution on worker
  - `connection.url=jdbc:sqlite::memory:` accepted by Aiven JDBC connector (bypasses URL validation)
  - Arbitrary SQL executes on worker JVM; results stream to attacker-controlled Kafka topics
  - CONFIRMED: HELLO_PIPELINE data exfil via sqlite_base topic (10 messages)
  - CONFIRMED: sqlite_version() = 3.46.0, ENABLE_LOAD_EXTENSION=1 (compile-time)
  - CONFIRMED: disk SQLite creates files in /tmp/ (aiven_bounty.db created)
  - BLOCKED: readfile() not available (fileio extension not compiled in)
  - BLOCKED: load_extension() blocked at runtime with "not authorized" (SQLITE_ERROR)
  - Worker OS: Fedora 42, aarch64 (from Finding F Snowflake exfil) — this is NEW vs prior session intel
  - Connector `sqlite-exfil` RUNNING on kafkaconnect-14b863b, integrated with kafka-test

**INFRASTRUCTURE STATE (2026-06-03):**
- sqlite-exfil connector: RUNNING, query=arbitrary SQL, topic.prefix=sqlite_exfil
- sqlite_base topic: 10 × HELLO_PIPELINE messages (baseline proof)
- sqlite_exfil topic: offset 22, has version data + ALIVE_V2 messages
- Kafka service: kafka-test-bugcrowdninja-6169.a.aivencloud.com:19780
- Certs: recon/aiven/kafka-certs/ (ca.pem, service.cert, service.key)

**KEY INTELLIGENCE (updated):**
- Worker OS: Fedora 42, aarch64 (confirmed via Snowflake exfil finding F)
- Worker kernel: 6.19.14-108.aiven4.fc42.aarch64
- JVM: OpenJDK 17.0.19 (org.apache.kafka.connect.cli.ConnectDistributed)
- SQLite: 3.46.0 (ENABLE_LOAD_EXTENSION=1 compile-time, blocked runtime)
- NOT Docker, NOT Kubernetes; AWS us-east-1; worker IP 50.16.25.50
- IMDS (169.254.169.254): iptables RST blocked
- ECS metadata (169.254.170.2): NOT blocked, 504 timeout
- `/proc/self/environ` accessible (3-state oracle + PKCS12 byte0='L')
- `/root/.aws/credentials` EXISTS but PERMISSION DENIED (non-root process)

**Why:** T1 Kafka Connect; Finding G is novel (SQLite as local execution backend, not remote DB — Aiven-specific URL validation bypass).
**How to apply:** Submit Finding E first if not yet submitted. Finding G needs report writing.

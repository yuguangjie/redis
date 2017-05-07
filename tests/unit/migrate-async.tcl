start_server {tags {"migrate-async"}} {
    test {RESTORE-ASYNC-AUTH fails if there is no password configured server side} {
        assert_match {RESTORE-ASYNC-ACK 1 *} [r restore-async-auth foo]
    }
}

start_server {tags {"migrate-async"} overrides {requirepass foobar}} {
    test {RESTORE-ASYNC-AUTH fails when a wrong password is given} {
        assert_match {RESTORE-ASYNC-ACK 1 *} [r restore-async-auth wrong_passwd]
    }
}

start_server {tags {"migrate-async"} overrides {requirepass foobar}} {
    test {RESTORE-ASYNC-SELECT fails when password is not given} {
        catch {r restore-async-select 1} err
        assert_match {NOAUTH*} $err
    }

    test {RESTORE-ASYNC-AUTH succeeds when the right password is given} {
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async-auth foobar]
    }

    test {RESTORE-ASYNC-AUTH succeeded then we can actually send commands to the server} {
        assert_equal OK [r set foo 100]
        assert_equal {101} [r incr foo]
    }
}

start_server {tags {"migrate-async"}} {
    test {RESTORE-ASYNC-SELECT can change database} {
        r select 0
        r set foo 100

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async-select 0]
        assert_equal {101} [r incr foo]

        r select 1
        r set foo 200

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async-select 1]
        assert_equal {201} [r incr foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async-select 0]
        assert_equal {102} [r incr foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async-select 1]
        assert_equal {202} [r incr foo]
    }

    test {RESTORE-ASYNC DELETE against a single item} {
        r set foo hello
        assert_equal {hello} [r get foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async delete foo]
        assert_equal {} [r get foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async delete foo]
        assert_equal {} [r get foo]
    }
}

start_server {tags {"migrate-async"}} {
    test {RESTORE-ASYNC STRING against a string item} {
        r del foo
        assert_equal {} [r get foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async string foo 0 hello]
        assert_equal {hello} [r get foo]
        assert_equal {-1} [r pttl foo]

        r del foo
        assert_equal {} [r get foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async string foo 5000 world]
        assert_equal {world} [r get foo]
        set ttl [r pttl foo]
        assert {$ttl >= 3000 && $ttl <= 5000}

        r del bar
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async string bar 0 10000]
        assert_equal {10001} [r incr bar]
    }

    test {RESTORE-ASYNC STRING against a string item (already exists)} {
        r set var exists
        assert_match {RESTORE-ASYNC-ACK 1 *} [r restore-async string var 0 payload]
    }
}

start_server {tags {"migrate-async"}} {
    test {RESTORE-ASYNC LIST against a list item} {
        r del foo
        assert_equal {0} [r llen foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async list foo 0 0 a1 a2]
        assert_equal {2} [r llen foo]
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async list foo 0 0 b1 b2]
        assert_equal {4} [r llen foo]
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async list foo 0 0 c1 c2]
        assert_equal {6} [r llen foo]
        assert_equal {-1} [r pttl foo]
        assert_encoding quicklist foo
        assert_equal {a1} [r lindex foo 0]
        assert_equal {a2} [r lindex foo 1]
        assert_equal {b1} [r lindex foo 2]
        assert_equal {b2} [r lindex foo 3]
        assert_equal {c1} [r lindex foo 4]
        assert_equal {c2} [r lindex foo 5]
    }

    test {RESTORE-ASYNC HASH against a hash item} {
        r del foo
        assert_equal {0} [r hlen foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async hash foo 0 0 k1 v1 k2 v2]
        assert_equal {2} [r hlen foo]
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async hash foo 0 0 k3 v3 k1 v4]
        assert_equal {3} [r hlen foo]
        assert_equal {-1} [r pttl foo]
        assert_encoding hashtable foo
        assert_equal {v4 v2 v3} [r hmget foo k1 k2 k3]
    }

    test {RESTORE-ASYNC DICT against a set item} {
        r del foo
        assert_equal {0} [r scard foo]

        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async dict foo 0 0 e1 e2 e3]
        assert_equal {3} [r scard foo]
        assert_match {RESTORE-ASYNC-ACK 0 *} [r restore-async dict foo 0 0 e1 e2 e4]
        assert_equal {4} [r scard foo]
        assert_equal {-1} [r pttl foo]
        assert_encoding hashtable foo
        assert_equal {1} [r sismember foo e1]
        assert_equal {1} [r sismember foo e2]
        assert_equal {1} [r sismember foo e3]
        assert_equal {1} [r sismember foo e4]
    }
}

package com.backpackcorp.backpack.user.domain;

// users.role 컬럼 값(ck_users_role)과 JWT의 role 클레임에 그대로 쓰인다
public enum Role {
	USER,
	ADMIN
}

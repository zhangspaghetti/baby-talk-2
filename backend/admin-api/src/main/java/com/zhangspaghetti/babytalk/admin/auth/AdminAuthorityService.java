package com.zhangspaghetti.babytalk.admin.auth;

import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Service;

@Service
public class AdminAuthorityService {

    private final AdminRbacRepository adminRbacRepository;

    public AdminAuthorityService(AdminRbacRepository adminRbacRepository) {
        this.adminRbacRepository = adminRbacRepository;
    }

    public AuthoritySnapshot loadCurrentAuthorities(String principalId) {
        var snapshot = adminRbacRepository.findAuthoritySnapshot(principalId);
        return new AuthoritySnapshot(principalId, snapshot.roleCodes(), snapshot.permissionCodes());
    }

    private static String roleAuthority(String roleCode) {
        return "ROLE_" + roleCode.replace('-', '_').toUpperCase();
    }

    public record AuthoritySnapshot(
            String principalId,
            List<String> roleCodes,
            List<String> permissionCodes
    ) {

        public Collection<SimpleGrantedAuthority> grantedAuthorities() {
            var authorities = new LinkedHashSet<SimpleGrantedAuthority>();
            roleCodes.stream()
                    .map(AdminAuthorityService::roleAuthority)
                    .map(SimpleGrantedAuthority::new)
                    .forEach(authorities::add);
            permissionCodes.stream()
                    .map(SimpleGrantedAuthority::new)
                    .forEach(authorities::add);
            return List.copyOf(authorities);
        }
    }
}

# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: knowledge-ops.spec.ts >> knowledge ops workspace >> handles real ingestion upload/failure/retry and KG mark-read/resolve while keeping context inline
- Location: ..\..\..\..\..\..\..\Users\zhang\.gsd\projects\67565506c51a\worktrees\M006\admin-web\tests\knowledge-ops.spec.ts:22:3

# Error details

```
Error: expect(received).toBe(expected) // Object.is equality

Expected: 9
Received: 11
```

# Page snapshot

```yaml
- generic [ref=e5]:
  - complementary [ref=e7]:
    - generic [ref=e8]:
      - generic [ref=e10] [cursor=pointer]:
        - generic [ref=e11]: BT
        - heading "BabyTalk Admin" [level=1] [ref=e12]
      - menu [ref=e14]:
        - menuitem "home Overview" [ref=e15] [cursor=pointer]:
          - link "home Overview" [ref=e17]:
            - /url: /overview
            - generic [ref=e18]:
              - img "home" [ref=e20]:
                - img [ref=e21]
              - generic [ref=e23]: Overview
        - menuitem "team Users" [ref=e24] [cursor=pointer]:
          - link "team Users" [ref=e26]:
            - /url: /users
            - generic [ref=e27]:
              - img "team" [ref=e29]:
                - img [ref=e30]
              - generic [ref=e32]: Users
        - menuitem "read Knowledge Ops" [ref=e33] [cursor=pointer]:
          - link "read Knowledge Ops" [ref=e35]:
            - /url: /knowledge-ops
            - generic [ref=e36]:
              - img "read" [ref=e38]:
                - img [ref=e39]
              - generic [ref=e41]: Knowledge Ops
        - menuitem "safety-certificate Mentor Audit" [ref=e42] [cursor=pointer]:
          - link "safety-certificate Mentor Audit" [ref=e44]:
            - /url: /mentor/audits
            - generic [ref=e45]:
              - img "safety-certificate" [ref=e47]:
                - img [ref=e48]
              - generic [ref=e50]: Mentor Audit
        - menuitem "bar-chart Distribution Stats" [ref=e51] [cursor=pointer]:
          - link "bar-chart Distribution Stats" [ref=e53]:
            - /url: /distribution/stats
            - generic [ref=e54]:
              - img "bar-chart" [ref=e56]:
                - img [ref=e57]
              - generic [ref=e59]: Distribution Stats
      - generic [ref=e60]:
        - generic [ref=e61]:
          - generic [ref=e63]:
            - img "user" [ref=e65] [cursor=pointer]:
              - img [ref=e66]
            - generic [ref=e68] [cursor=pointer]: Super Admin
          - generic [ref=e69]: super_admin
        - generic [ref=e70]:
          - generic [ref=e73] [cursor=pointer]: Knowledge Ops
          - button "logout 退出登录" [ref=e76] [cursor=pointer]:
            - img "logout" [ref=e78]:
              - img [ref=e79]
            - generic [ref=e81]: 退出登录
      - img [ref=e83] [cursor=pointer]
  - main [ref=e86]:
    - generic [ref=e87]:
      - generic [ref=e88]:
        - navigation [ref=e89]:
          - list [ref=e90]:
            - listitem [ref=e91]: Admin Shell
            - listitem [ref=e92]: /
            - listitem [ref=e93]: Knowledge Ops
        - generic [ref=e95]:
          - generic "Knowledge Ops" [ref=e96]
          - generic "ingestion queue、upload/retry、KG contradiction review 与通知处理的真实工作面。" [ref=e97]
        - generic [ref=e101]:
          - generic [ref=e103]: super_admin 默认落到 Overview，避免多模块账号直接跳进某个单工作面。
          - generic [ref=e105]:
            - generic [ref=e107]:
              - generic [ref=e109]: "user: super_admin"
              - generic [ref=e111]: "current: Knowledge Ops"
              - generic [ref=e113]: "visible modules: 5"
            - generic [ref=e115]:
              - generic [ref=e117]: Overview
              - generic [ref=e119]: Users
              - generic [ref=e121]: Knowledge Ops
              - generic [ref=e123]: Mentor Audit
              - generic [ref=e125]: Distribution Stats
            - generic [ref=e129]: super_admin
            - generic [ref=e131]:
              - generic [ref=e133]: admins:read
              - generic [ref=e135]: admins:write
              - generic [ref=e137]: distribution:read
              - generic [ref=e139]: kg:read
              - generic [ref=e141]: kg:review
              - generic [ref=e143]: mentor:audit
              - generic [ref=e145]: rag:read
              - generic [ref=e147]: rag:write
              - generic [ref=e149]: rbac:read
              - generic [ref=e151]: rbac:write
              - generic [ref=e153]: users:read
              - generic [ref=e155]: users:write
            - generic [ref=e157]:
              - generic [ref=e159]: "access token expires at: 2026-04-24T18:53:13.710378969Z"
              - generic [ref=e161]: "refresh token expires at: 2026-05-01T18:38:13.799852269Z"
      - generic [ref=e165]:
        - generic [ref=e167]:
          - heading "Knowledge Ops Workbench" [level=3] [ref=e169]
          - generic [ref=e171]: "单一路由 `/knowledge-ops` 挂两个真实工作面：ingestion queue 与 KG contradiction review。view / status / selected 全部以 URL query 为真相源，失败态会留在当前页面而不是把 operator 弹走。"
        - generic [ref=e173]:
          - generic [ref=e176]: Current admin / capabilities
          - generic [ref=e178]:
            - generic [ref=e180]:
              - generic [ref=e182]: "user: super_admin"
              - generic [ref=e184]: rag:read enabled
              - generic [ref=e186]: rag:write enabled
              - generic [ref=e188]: kg:read enabled
              - generic [ref=e190]: kg:review enabled
              - generic [ref=e192]: "roles: super_admin"
              - generic [ref=e194]: "access expires: 4/25/2026, 2:53:13 AM"
            - generic [ref=e196]:
              - generic [ref=e198]: "view: ingestion"
              - generic [ref=e200]: "status: all"
              - generic [ref=e202]: "selected: effc14e7-ae82-499b-9034-f4b57009f8c2"
              - generic [ref=e204]: "queue freshness: polling 7"
              - generic [ref=e206]: "updatedAt: 4/25/2026, 2:38:44 AM"
            - code [ref=e209]: view=ingestion&status=all&selected=effc14e7-ae82-499b-9034-f4b57009f8c2
        - generic [ref=e211]:
          - generic [ref=e214]: Workbench surfaces
          - generic [ref=e216]:
            - button "Ingestion" [ref=e218] [cursor=pointer]:
              - generic [ref=e219]: Ingestion
            - button "KG Review" [ref=e221] [cursor=pointer]:
              - generic [ref=e222]: KG Review
        - generic [ref=e224]:
          - generic [ref=e227]: Inline diagnostics
          - generic [ref=e229]:
            - generic [ref=e230]: "malformed payload 会在 client parser 边界抛出 `invalid_response_payload`；timeout 会把 ingestion surface 标成 stale，并保留当前 URL / selected context。"
            - generic [ref=e232]:
              - generic [ref=e234]: "list: ready"
              - generic [ref=e236]: "detail: ready"
              - generic [ref=e238]: "poll: 7/8"
        - generic [ref=e240]:
          - generic [ref=e243]: Ingestion controls
          - generic [ref=e245]:
            - generic [ref=e247]:
              - text: status filter
              - generic [ref=e248]:
                - button "全 部" [ref=e250] [cursor=pointer]:
                  - generic [ref=e251]: 全 部
                - button "PENDING" [ref=e253] [cursor=pointer]:
                  - generic [ref=e254]: PENDING
                - button "PROCESSING" [ref=e256] [cursor=pointer]:
                  - generic [ref=e257]: PROCESSING
                - button "COMPLETED" [ref=e259] [cursor=pointer]:
                  - generic [ref=e260]: COMPLETED
                - button "FAILED" [ref=e262] [cursor=pointer]:
                  - generic [ref=e263]: FAILED
            - button "重新读取 queue" [ref=e267] [cursor=pointer]:
              - generic [ref=e268]: 重新读取 queue
            - generic [ref=e270]:
              - generic [ref=e272]:
                - text: bookTitle
                - textbox "可选：书名/上传批次标记" [ref=e273]
              - generic [ref=e275]:
                - text: PDF file
                - button "Choose File" [ref=e276]
              - generic [ref=e278]:
                - button "上传 PDF" [active] [ref=e280] [cursor=pointer]:
                  - generic [ref=e281]: 上传 PDF
                - generic [ref=e283]: 未选择文件
            - alert [ref=e285]:
              - img "check-circle" [ref=e286]:
                - img [ref=e287]
              - generic [ref=e289]:
                - generic [ref=e290]: 上传任务已完成
                - generic [ref=e291]: jobId=effc14e7-ae82-499b-9034-f4b57009f8c2; status=COMPLETED; totalChunks=1; updatedAt=4/25/2026, 2:38:25 AM
        - generic [ref=e293]:
          - generic [ref=e294]:
            - generic [ref=e297]: Ingestion jobs (20)
            - list [ref=e302]:
              - listitem [ref=e303]:
                - generic [ref=e304]:
                  - generic [ref=e306]:
                    - generic [ref=e308]:
                      - code [ref=e311]: effc14e7-ae82-499b-9034-f4b57009f8c2
                      - generic [ref=e313]: COMPLETED
                    - button "已打开" [ref=e315] [cursor=pointer]:
                      - generic [ref=e316]: 已打开
                  - table [ref=e320]:
                    - rowgroup [ref=e321]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e322]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e323]':
                          - generic [ref=e324]:
                            - generic [ref=e325]: "filename :"
                            - generic [ref=e326]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e327]':
                        - 'cell "totalChunks : 1" [ref=e328]':
                          - generic [ref=e329]:
                            - generic [ref=e330]: "totalChunks :"
                            - generic [ref=e331]: "1"
                      - 'row "updatedAt : 4/25/2026, 2:38:25 AM" [ref=e332]':
                        - 'cell "updatedAt : 4/25/2026, 2:38:25 AM" [ref=e333]':
                          - generic [ref=e334]:
                            - generic [ref=e335]: "updatedAt :"
                            - generic [ref=e336]: 4/25/2026, 2:38:25 AM
                      - 'row "errorMessage : —" [ref=e337]':
                        - 'cell "errorMessage : —" [ref=e338]':
                          - generic [ref=e339]:
                            - generic [ref=e340]: "errorMessage :"
                            - generic [ref=e341]: —
              - listitem [ref=e342]:
                - generic [ref=e343]:
                  - generic [ref=e345]:
                    - generic [ref=e347]:
                      - code [ref=e350]: 6c232c9d-c3ff-4e63-827e-75fcd97d1564
                      - generic [ref=e352]: COMPLETED
                    - button "查看详情" [ref=e354] [cursor=pointer]:
                      - generic [ref=e355]: 查看详情
                  - table [ref=e359]:
                    - rowgroup [ref=e360]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e361]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e362]':
                          - generic [ref=e363]:
                            - generic [ref=e364]: "filename :"
                            - generic [ref=e365]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e366]':
                        - 'cell "totalChunks : 1" [ref=e367]':
                          - generic [ref=e368]:
                            - generic [ref=e369]: "totalChunks :"
                            - generic [ref=e370]: "1"
                      - 'row "updatedAt : 4/25/2026, 12:06:43 AM" [ref=e371]':
                        - 'cell "updatedAt : 4/25/2026, 12:06:43 AM" [ref=e372]':
                          - generic [ref=e373]:
                            - generic [ref=e374]: "updatedAt :"
                            - generic [ref=e375]: 4/25/2026, 12:06:43 AM
                      - 'row "errorMessage : —" [ref=e376]':
                        - 'cell "errorMessage : —" [ref=e377]':
                          - generic [ref=e378]:
                            - generic [ref=e379]: "errorMessage :"
                            - generic [ref=e380]: —
              - listitem [ref=e381]:
                - generic [ref=e382]:
                  - generic [ref=e384]:
                    - generic [ref=e386]:
                      - code [ref=e389]: ebe5861e-c98a-4c8d-8d50-7c14b12ab865
                      - generic [ref=e391]: FAILED
                      - generic [ref=e393]: retryable
                    - button "查看详情" [ref=e395] [cursor=pointer]:
                      - generic [ref=e396]: 查看详情
                  - table [ref=e400]:
                    - rowgroup [ref=e401]:
                      - 'row "filename : forced-mod3swm93dto4j.pdf" [ref=e402]':
                        - 'cell "filename : forced-mod3swm93dto4j.pdf" [ref=e403]':
                          - generic [ref=e404]:
                            - generic [ref=e405]: "filename :"
                            - generic [ref=e406]: forced-mod3swm93dto4j.pdf
                      - 'row "totalChunks : 0" [ref=e407]':
                        - 'cell "totalChunks : 0" [ref=e408]':
                          - generic [ref=e409]:
                            - generic [ref=e410]: "totalChunks :"
                            - generic [ref=e411]: "0"
                      - 'row "updatedAt : 4/25/2026, 12:06:16 AM" [ref=e412]':
                        - 'cell "updatedAt : 4/25/2026, 12:06:16 AM" [ref=e413]':
                          - generic [ref=e414]:
                            - generic [ref=e415]: "updatedAt :"
                            - generic [ref=e416]: 4/25/2026, 12:06:16 AM
                      - 'row "errorMessage : forced failure mod3swm93dto4j" [ref=e417]':
                        - 'cell "errorMessage : forced failure mod3swm93dto4j" [ref=e418]':
                          - generic [ref=e419]:
                            - generic [ref=e420]: "errorMessage :"
                            - generic [ref=e421]: forced failure mod3swm93dto4j
              - listitem [ref=e422]:
                - generic [ref=e423]:
                  - generic [ref=e425]:
                    - generic [ref=e427]:
                      - code [ref=e430]: a9d8d709-b190-4f46-b740-e59ee7fcae45
                      - generic [ref=e432]: PENDING
                    - button "查看详情" [ref=e434] [cursor=pointer]:
                      - generic [ref=e435]: 查看详情
                  - table [ref=e439]:
                    - rowgroup [ref=e440]:
                      - 'row "filename : stale-fixture.pdf" [ref=e441]':
                        - 'cell "filename : stale-fixture.pdf" [ref=e442]':
                          - generic [ref=e443]:
                            - generic [ref=e444]: "filename :"
                            - generic [ref=e445]: stale-fixture.pdf
                      - 'row "totalChunks : 0" [ref=e446]':
                        - 'cell "totalChunks : 0" [ref=e447]':
                          - generic [ref=e448]:
                            - generic [ref=e449]: "totalChunks :"
                            - generic [ref=e450]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:25:40 PM" [ref=e451]':
                        - 'cell "updatedAt : 4/24/2026, 10:25:40 PM" [ref=e452]':
                          - generic [ref=e453]:
                            - generic [ref=e454]: "updatedAt :"
                            - generic [ref=e455]: 4/24/2026, 10:25:40 PM
                      - 'row "errorMessage : —" [ref=e456]':
                        - 'cell "errorMessage : —" [ref=e457]':
                          - generic [ref=e458]:
                            - generic [ref=e459]: "errorMessage :"
                            - generic [ref=e460]: —
              - listitem [ref=e461]:
                - generic [ref=e462]:
                  - generic [ref=e464]:
                    - generic [ref=e466]:
                      - code [ref=e469]: b325b280-875e-41c7-860a-42261613dfbf
                      - generic [ref=e471]: COMPLETED
                    - button "查看详情" [ref=e473] [cursor=pointer]:
                      - generic [ref=e474]: 查看详情
                  - table [ref=e478]:
                    - rowgroup [ref=e479]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e480]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e481]':
                          - generic [ref=e482]:
                            - generic [ref=e483]: "filename :"
                            - generic [ref=e484]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e485]':
                        - 'cell "totalChunks : 1" [ref=e486]':
                          - generic [ref=e487]:
                            - generic [ref=e488]: "totalChunks :"
                            - generic [ref=e489]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:23:03 PM" [ref=e490]':
                        - 'cell "updatedAt : 4/24/2026, 10:23:03 PM" [ref=e491]':
                          - generic [ref=e492]:
                            - generic [ref=e493]: "updatedAt :"
                            - generic [ref=e494]: 4/24/2026, 10:23:03 PM
                      - 'row "errorMessage : —" [ref=e495]':
                        - 'cell "errorMessage : —" [ref=e496]':
                          - generic [ref=e497]:
                            - generic [ref=e498]: "errorMessage :"
                            - generic [ref=e499]: —
              - listitem [ref=e500]:
                - generic [ref=e501]:
                  - generic [ref=e503]:
                    - generic [ref=e505]:
                      - code [ref=e508]: 7f55ae1a-f724-4dc6-876c-7cd6f5b66b5e
                      - generic [ref=e510]: COMPLETED
                    - button "查看详情" [ref=e512] [cursor=pointer]:
                      - generic [ref=e513]: 查看详情
                  - table [ref=e517]:
                    - rowgroup [ref=e518]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e519]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e520]':
                          - generic [ref=e521]:
                            - generic [ref=e522]: "filename :"
                            - generic [ref=e523]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e524]':
                        - 'cell "totalChunks : 1" [ref=e525]':
                          - generic [ref=e526]:
                            - generic [ref=e527]: "totalChunks :"
                            - generic [ref=e528]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:22:51 PM" [ref=e529]':
                        - 'cell "updatedAt : 4/24/2026, 10:22:51 PM" [ref=e530]':
                          - generic [ref=e531]:
                            - generic [ref=e532]: "updatedAt :"
                            - generic [ref=e533]: 4/24/2026, 10:22:51 PM
                      - 'row "errorMessage : —" [ref=e534]':
                        - 'cell "errorMessage : —" [ref=e535]':
                          - generic [ref=e536]:
                            - generic [ref=e537]: "errorMessage :"
                            - generic [ref=e538]: —
              - listitem [ref=e539]:
                - generic [ref=e540]:
                  - generic [ref=e542]:
                    - generic [ref=e544]:
                      - code [ref=e547]: f08eda3e-bcc5-4ee1-b3e8-6839acf8d17e
                      - generic [ref=e549]: FAILED
                      - generic [ref=e551]: retryable
                    - button "查看详情" [ref=e553] [cursor=pointer]:
                      - generic [ref=e554]: 查看详情
                  - table [ref=e558]:
                    - rowgroup [ref=e559]:
                      - 'row "filename : forced-mod034532seswx.pdf" [ref=e560]':
                        - 'cell "filename : forced-mod034532seswx.pdf" [ref=e561]':
                          - generic [ref=e562]:
                            - generic [ref=e563]: "filename :"
                            - generic [ref=e564]: forced-mod034532seswx.pdf
                      - 'row "totalChunks : 0" [ref=e565]':
                        - 'cell "totalChunks : 0" [ref=e566]':
                          - generic [ref=e567]:
                            - generic [ref=e568]: "totalChunks :"
                            - generic [ref=e569]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:22:12 PM" [ref=e570]':
                        - 'cell "updatedAt : 4/24/2026, 10:22:12 PM" [ref=e571]':
                          - generic [ref=e572]:
                            - generic [ref=e573]: "updatedAt :"
                            - generic [ref=e574]: 4/24/2026, 10:22:12 PM
                      - 'row "errorMessage : forced failure mod034532seswx" [ref=e575]':
                        - 'cell "errorMessage : forced failure mod034532seswx" [ref=e576]':
                          - generic [ref=e577]:
                            - generic [ref=e578]: "errorMessage :"
                            - generic [ref=e579]: forced failure mod034532seswx
              - listitem [ref=e580]:
                - generic [ref=e581]:
                  - generic [ref=e583]:
                    - generic [ref=e585]:
                      - code [ref=e588]: d59b3f70-f243-464f-a34e-509d58dadd84
                      - generic [ref=e590]: COMPLETED
                    - button "查看详情" [ref=e592] [cursor=pointer]:
                      - generic [ref=e593]: 查看详情
                  - table [ref=e597]:
                    - rowgroup [ref=e598]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e599]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e600]':
                          - generic [ref=e601]:
                            - generic [ref=e602]: "filename :"
                            - generic [ref=e603]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e604]':
                        - 'cell "totalChunks : 1" [ref=e605]':
                          - generic [ref=e606]:
                            - generic [ref=e607]: "totalChunks :"
                            - generic [ref=e608]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:07:03 PM" [ref=e609]':
                        - 'cell "updatedAt : 4/24/2026, 10:07:03 PM" [ref=e610]':
                          - generic [ref=e611]:
                            - generic [ref=e612]: "updatedAt :"
                            - generic [ref=e613]: 4/24/2026, 10:07:03 PM
                      - 'row "errorMessage : —" [ref=e614]':
                        - 'cell "errorMessage : —" [ref=e615]':
                          - generic [ref=e616]:
                            - generic [ref=e617]: "errorMessage :"
                            - generic [ref=e618]: —
              - listitem [ref=e619]:
                - generic [ref=e620]:
                  - generic [ref=e622]:
                    - generic [ref=e624]:
                      - code [ref=e627]: badc28c9-0423-4491-ad2a-3a802571697d
                      - generic [ref=e629]: COMPLETED
                    - button "查看详情" [ref=e631] [cursor=pointer]:
                      - generic [ref=e632]: 查看详情
                  - table [ref=e636]:
                    - rowgroup [ref=e637]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e638]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e639]':
                          - generic [ref=e640]:
                            - generic [ref=e641]: "filename :"
                            - generic [ref=e642]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e643]':
                        - 'cell "totalChunks : 1" [ref=e644]':
                          - generic [ref=e645]:
                            - generic [ref=e646]: "totalChunks :"
                            - generic [ref=e647]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:06:48 PM" [ref=e648]':
                        - 'cell "updatedAt : 4/24/2026, 10:06:48 PM" [ref=e649]':
                          - generic [ref=e650]:
                            - generic [ref=e651]: "updatedAt :"
                            - generic [ref=e652]: 4/24/2026, 10:06:48 PM
                      - 'row "errorMessage : —" [ref=e653]':
                        - 'cell "errorMessage : —" [ref=e654]':
                          - generic [ref=e655]:
                            - generic [ref=e656]: "errorMessage :"
                            - generic [ref=e657]: —
              - listitem [ref=e658]:
                - generic [ref=e659]:
                  - generic [ref=e661]:
                    - generic [ref=e663]:
                      - code [ref=e666]: 0a87fb99-292d-485e-b559-5b044ea67c27
                      - generic [ref=e668]: FAILED
                      - generic [ref=e670]: retryable
                    - button "查看详情" [ref=e672] [cursor=pointer]:
                      - generic [ref=e673]: 查看详情
                  - table [ref=e677]:
                    - rowgroup [ref=e678]:
                      - 'row "filename : forced-moczijmv3hmhet.pdf" [ref=e679]':
                        - 'cell "filename : forced-moczijmv3hmhet.pdf" [ref=e680]':
                          - generic [ref=e681]:
                            - generic [ref=e682]: "filename :"
                            - generic [ref=e683]: forced-moczijmv3hmhet.pdf
                      - 'row "totalChunks : 0" [ref=e684]':
                        - 'cell "totalChunks : 0" [ref=e685]':
                          - generic [ref=e686]:
                            - generic [ref=e687]: "totalChunks :"
                            - generic [ref=e688]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:06:12 PM" [ref=e689]':
                        - 'cell "updatedAt : 4/24/2026, 10:06:12 PM" [ref=e690]':
                          - generic [ref=e691]:
                            - generic [ref=e692]: "updatedAt :"
                            - generic [ref=e693]: 4/24/2026, 10:06:12 PM
                      - 'row "errorMessage : forced failure moczijmv3hmhet" [ref=e694]':
                        - 'cell "errorMessage : forced failure moczijmv3hmhet" [ref=e695]':
                          - generic [ref=e696]:
                            - generic [ref=e697]: "errorMessage :"
                            - generic [ref=e698]: forced failure moczijmv3hmhet
              - listitem [ref=e699]:
                - generic [ref=e700]:
                  - generic [ref=e702]:
                    - generic [ref=e704]:
                      - code [ref=e707]: 61161aeb-1b33-4aeb-92be-32ad5e24234b
                      - generic [ref=e709]: COMPLETED
                    - button "查看详情" [ref=e711] [cursor=pointer]:
                      - generic [ref=e712]: 查看详情
                  - table [ref=e716]:
                    - rowgroup [ref=e717]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e718]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e719]':
                          - generic [ref=e720]:
                            - generic [ref=e721]: "filename :"
                            - generic [ref=e722]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e723]':
                        - 'cell "totalChunks : 1" [ref=e724]':
                          - generic [ref=e725]:
                            - generic [ref=e726]: "totalChunks :"
                            - generic [ref=e727]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:59:20 PM" [ref=e728]':
                        - 'cell "updatedAt : 4/24/2026, 9:59:20 PM" [ref=e729]':
                          - generic [ref=e730]:
                            - generic [ref=e731]: "updatedAt :"
                            - generic [ref=e732]: 4/24/2026, 9:59:20 PM
                      - 'row "errorMessage : —" [ref=e733]':
                        - 'cell "errorMessage : —" [ref=e734]':
                          - generic [ref=e735]:
                            - generic [ref=e736]: "errorMessage :"
                            - generic [ref=e737]: —
              - listitem [ref=e738]:
                - generic [ref=e739]:
                  - generic [ref=e741]:
                    - generic [ref=e743]:
                      - code [ref=e746]: bef6223f-0f02-4f1a-b1c0-4c850f09324a
                      - generic [ref=e748]: COMPLETED
                    - button "查看详情" [ref=e750] [cursor=pointer]:
                      - generic [ref=e751]: 查看详情
                  - table [ref=e755]:
                    - rowgroup [ref=e756]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e757]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e758]':
                          - generic [ref=e759]:
                            - generic [ref=e760]: "filename :"
                            - generic [ref=e761]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e762]':
                        - 'cell "totalChunks : 1" [ref=e763]':
                          - generic [ref=e764]:
                            - generic [ref=e765]: "totalChunks :"
                            - generic [ref=e766]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:59:13 PM" [ref=e767]':
                        - 'cell "updatedAt : 4/24/2026, 9:59:13 PM" [ref=e768]':
                          - generic [ref=e769]:
                            - generic [ref=e770]: "updatedAt :"
                            - generic [ref=e771]: 4/24/2026, 9:59:13 PM
                      - 'row "errorMessage : —" [ref=e772]':
                        - 'cell "errorMessage : —" [ref=e773]':
                          - generic [ref=e774]:
                            - generic [ref=e775]: "errorMessage :"
                            - generic [ref=e776]: —
              - listitem [ref=e777]:
                - generic [ref=e778]:
                  - generic [ref=e780]:
                    - generic [ref=e782]:
                      - code [ref=e785]: 022a2f15-e134-4fd9-a9f3-de4726b2d449
                      - generic [ref=e787]: FAILED
                      - generic [ref=e789]: retryable
                    - button "查看详情" [ref=e791] [cursor=pointer]:
                      - generic [ref=e792]: 查看详情
                  - table [ref=e796]:
                    - rowgroup [ref=e797]:
                      - 'row "filename : forced-mocz8kspbuwlie.pdf" [ref=e798]':
                        - 'cell "filename : forced-mocz8kspbuwlie.pdf" [ref=e799]':
                          - generic [ref=e800]:
                            - generic [ref=e801]: "filename :"
                            - generic [ref=e802]: forced-mocz8kspbuwlie.pdf
                      - 'row "totalChunks : 0" [ref=e803]':
                        - 'cell "totalChunks : 0" [ref=e804]':
                          - generic [ref=e805]:
                            - generic [ref=e806]: "totalChunks :"
                            - generic [ref=e807]: "0"
                      - 'row "updatedAt : 4/24/2026, 9:58:27 PM" [ref=e808]':
                        - 'cell "updatedAt : 4/24/2026, 9:58:27 PM" [ref=e809]':
                          - generic [ref=e810]:
                            - generic [ref=e811]: "updatedAt :"
                            - generic [ref=e812]: 4/24/2026, 9:58:27 PM
                      - 'row "errorMessage : forced failure mocz8kspbuwlie" [ref=e813]':
                        - 'cell "errorMessage : forced failure mocz8kspbuwlie" [ref=e814]':
                          - generic [ref=e815]:
                            - generic [ref=e816]: "errorMessage :"
                            - generic [ref=e817]: forced failure mocz8kspbuwlie
              - listitem [ref=e818]:
                - generic [ref=e819]:
                  - generic [ref=e821]:
                    - generic [ref=e823]:
                      - code [ref=e826]: 7a0fcbaa-aecf-4bce-99c8-65d4dddb9627
                      - generic [ref=e828]: COMPLETED
                    - button "查看详情" [ref=e830] [cursor=pointer]:
                      - generic [ref=e831]: 查看详情
                  - table [ref=e835]:
                    - rowgroup [ref=e836]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e837]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e838]':
                          - generic [ref=e839]:
                            - generic [ref=e840]: "filename :"
                            - generic [ref=e841]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e842]':
                        - 'cell "totalChunks : 1" [ref=e843]':
                          - generic [ref=e844]:
                            - generic [ref=e845]: "totalChunks :"
                            - generic [ref=e846]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:52:27 PM" [ref=e847]':
                        - 'cell "updatedAt : 4/24/2026, 9:52:27 PM" [ref=e848]':
                          - generic [ref=e849]:
                            - generic [ref=e850]: "updatedAt :"
                            - generic [ref=e851]: 4/24/2026, 9:52:27 PM
                      - 'row "errorMessage : —" [ref=e852]':
                        - 'cell "errorMessage : —" [ref=e853]':
                          - generic [ref=e854]:
                            - generic [ref=e855]: "errorMessage :"
                            - generic [ref=e856]: —
              - listitem [ref=e857]:
                - generic [ref=e858]:
                  - generic [ref=e860]:
                    - generic [ref=e862]:
                      - code [ref=e865]: 4460c0d6-efdf-4aa9-a6f4-908340f2f724
                      - generic [ref=e867]: COMPLETED
                    - button "查看详情" [ref=e869] [cursor=pointer]:
                      - generic [ref=e870]: 查看详情
                  - table [ref=e874]:
                    - rowgroup [ref=e875]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e876]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e877]':
                          - generic [ref=e878]:
                            - generic [ref=e879]: "filename :"
                            - generic [ref=e880]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e881]':
                        - 'cell "totalChunks : 1" [ref=e882]':
                          - generic [ref=e883]:
                            - generic [ref=e884]: "totalChunks :"
                            - generic [ref=e885]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:52:19 PM" [ref=e886]':
                        - 'cell "updatedAt : 4/24/2026, 9:52:19 PM" [ref=e887]':
                          - generic [ref=e888]:
                            - generic [ref=e889]: "updatedAt :"
                            - generic [ref=e890]: 4/24/2026, 9:52:19 PM
                      - 'row "errorMessage : —" [ref=e891]':
                        - 'cell "errorMessage : —" [ref=e892]':
                          - generic [ref=e893]:
                            - generic [ref=e894]: "errorMessage :"
                            - generic [ref=e895]: —
              - listitem [ref=e896]:
                - generic [ref=e897]:
                  - generic [ref=e899]:
                    - generic [ref=e901]:
                      - code [ref=e904]: 543a906b-60e3-4ea9-ba7f-69216934855e
                      - generic [ref=e906]: FAILED
                      - generic [ref=e908]: retryable
                    - button "查看详情" [ref=e910] [cursor=pointer]:
                      - generic [ref=e911]: 查看详情
                  - table [ref=e915]:
                    - rowgroup [ref=e916]:
                      - 'row "filename : forced-mocyzoi5fdkw57.pdf" [ref=e917]':
                        - 'cell "filename : forced-mocyzoi5fdkw57.pdf" [ref=e918]':
                          - generic [ref=e919]:
                            - generic [ref=e920]: "filename :"
                            - generic [ref=e921]: forced-mocyzoi5fdkw57.pdf
                      - 'row "totalChunks : 0" [ref=e922]':
                        - 'cell "totalChunks : 0" [ref=e923]':
                          - generic [ref=e924]:
                            - generic [ref=e925]: "totalChunks :"
                            - generic [ref=e926]: "0"
                      - 'row "updatedAt : 4/24/2026, 9:51:32 PM" [ref=e927]':
                        - 'cell "updatedAt : 4/24/2026, 9:51:32 PM" [ref=e928]':
                          - generic [ref=e929]:
                            - generic [ref=e930]: "updatedAt :"
                            - generic [ref=e931]: 4/24/2026, 9:51:32 PM
                      - 'row "errorMessage : forced failure mocyzoi5fdkw57" [ref=e932]':
                        - 'cell "errorMessage : forced failure mocyzoi5fdkw57" [ref=e933]':
                          - generic [ref=e934]:
                            - generic [ref=e935]: "errorMessage :"
                            - generic [ref=e936]: forced failure mocyzoi5fdkw57
              - listitem [ref=e937]:
                - generic [ref=e938]:
                  - generic [ref=e940]:
                    - generic [ref=e942]:
                      - code [ref=e945]: 6c08fc8e-cac8-45e1-af17-c474d4f9723a
                      - generic [ref=e947]: COMPLETED
                    - button "查看详情" [ref=e949] [cursor=pointer]:
                      - generic [ref=e950]: 查看详情
                  - table [ref=e954]:
                    - rowgroup [ref=e955]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e956]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e957]':
                          - generic [ref=e958]:
                            - generic [ref=e959]: "filename :"
                            - generic [ref=e960]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e961]':
                        - 'cell "totalChunks : 1" [ref=e962]':
                          - generic [ref=e963]:
                            - generic [ref=e964]: "totalChunks :"
                            - generic [ref=e965]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:48:35 PM" [ref=e966]':
                        - 'cell "updatedAt : 4/24/2026, 9:48:35 PM" [ref=e967]':
                          - generic [ref=e968]:
                            - generic [ref=e969]: "updatedAt :"
                            - generic [ref=e970]: 4/24/2026, 9:48:35 PM
                      - 'row "errorMessage : —" [ref=e971]':
                        - 'cell "errorMessage : —" [ref=e972]':
                          - generic [ref=e973]:
                            - generic [ref=e974]: "errorMessage :"
                            - generic [ref=e975]: —
              - listitem [ref=e976]:
                - generic [ref=e977]:
                  - generic [ref=e979]:
                    - generic [ref=e981]:
                      - code [ref=e984]: 0cba9b57-032d-4681-9cd0-d026a24ac150
                      - generic [ref=e986]: COMPLETED
                    - button "查看详情" [ref=e988] [cursor=pointer]:
                      - generic [ref=e989]: 查看详情
                  - table [ref=e993]:
                    - rowgroup [ref=e994]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e995]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e996]':
                          - generic [ref=e997]:
                            - generic [ref=e998]: "filename :"
                            - generic [ref=e999]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e1000]':
                        - 'cell "totalChunks : 1" [ref=e1001]':
                          - generic [ref=e1002]:
                            - generic [ref=e1003]: "totalChunks :"
                            - generic [ref=e1004]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:48:24 PM" [ref=e1005]':
                        - 'cell "updatedAt : 4/24/2026, 9:48:24 PM" [ref=e1006]':
                          - generic [ref=e1007]:
                            - generic [ref=e1008]: "updatedAt :"
                            - generic [ref=e1009]: 4/24/2026, 9:48:24 PM
                      - 'row "errorMessage : —" [ref=e1010]':
                        - 'cell "errorMessage : —" [ref=e1011]':
                          - generic [ref=e1012]:
                            - generic [ref=e1013]: "errorMessage :"
                            - generic [ref=e1014]: —
              - listitem [ref=e1015]:
                - generic [ref=e1016]:
                  - generic [ref=e1018]:
                    - generic [ref=e1020]:
                      - code [ref=e1023]: b412b0e4-7633-43a5-862b-166b20ebdfc3
                      - generic [ref=e1025]: FAILED
                      - generic [ref=e1027]: retryable
                    - button "查看详情" [ref=e1029] [cursor=pointer]:
                      - generic [ref=e1030]: 查看详情
                  - table [ref=e1034]:
                    - rowgroup [ref=e1035]:
                      - 'row "filename : forced-mocyus7i9su3p0.pdf" [ref=e1036]':
                        - 'cell "filename : forced-mocyus7i9su3p0.pdf" [ref=e1037]':
                          - generic [ref=e1038]:
                            - generic [ref=e1039]: "filename :"
                            - generic [ref=e1040]: forced-mocyus7i9su3p0.pdf
                      - 'row "totalChunks : 0" [ref=e1041]':
                        - 'cell "totalChunks : 0" [ref=e1042]':
                          - generic [ref=e1043]:
                            - generic [ref=e1044]: "totalChunks :"
                            - generic [ref=e1045]: "0"
                      - 'row "updatedAt : 4/24/2026, 9:47:43 PM" [ref=e1046]':
                        - 'cell "updatedAt : 4/24/2026, 9:47:43 PM" [ref=e1047]':
                          - generic [ref=e1048]:
                            - generic [ref=e1049]: "updatedAt :"
                            - generic [ref=e1050]: 4/24/2026, 9:47:43 PM
                      - 'row "errorMessage : forced failure mocyus7i9su3p0" [ref=e1051]':
                        - 'cell "errorMessage : forced failure mocyus7i9su3p0" [ref=e1052]':
                          - generic [ref=e1053]:
                            - generic [ref=e1054]: "errorMessage :"
                            - generic [ref=e1055]: forced failure mocyus7i9su3p0
              - listitem [ref=e1056]:
                - generic [ref=e1057]:
                  - generic [ref=e1059]:
                    - generic [ref=e1061]:
                      - code [ref=e1064]: b0f45213-bdb9-4234-bea8-301a7cc2b2ae
                      - generic [ref=e1066]: COMPLETED
                    - button "查看详情" [ref=e1068] [cursor=pointer]:
                      - generic [ref=e1069]: 查看详情
                  - table [ref=e1073]:
                    - rowgroup [ref=e1074]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e1075]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e1076]':
                          - generic [ref=e1077]:
                            - generic [ref=e1078]: "filename :"
                            - generic [ref=e1079]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e1080]':
                        - 'cell "totalChunks : 1" [ref=e1081]':
                          - generic [ref=e1082]:
                            - generic [ref=e1083]: "totalChunks :"
                            - generic [ref=e1084]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:45:42 PM" [ref=e1085]':
                        - 'cell "updatedAt : 4/24/2026, 9:45:42 PM" [ref=e1086]':
                          - generic [ref=e1087]:
                            - generic [ref=e1088]: "updatedAt :"
                            - generic [ref=e1089]: 4/24/2026, 9:45:42 PM
                      - 'row "errorMessage : —" [ref=e1090]':
                        - 'cell "errorMessage : —" [ref=e1091]':
                          - generic [ref=e1092]:
                            - generic [ref=e1093]: "errorMessage :"
                            - generic [ref=e1094]: —
          - generic [ref=e1095]:
            - generic [ref=e1097]:
              - generic [ref=e1098]: Ingestion detail · effc14e7-ae82-499b-9034-f4b57009f8c2
              - generic [ref=e1100]:
                - button "关闭详情" [ref=e1102] [cursor=pointer]:
                  - generic [ref=e1103]: 关闭详情
                - button "重试 detail" [ref=e1105] [cursor=pointer]:
                  - generic [ref=e1106]: 重试 detail
            - generic [ref=e1108]:
              - table [ref=e1112]:
                - rowgroup [ref=e1113]:
                  - row "jobId effc14e7-ae82-499b-9034-f4b57009f8c2" [ref=e1114]:
                    - rowheader "jobId" [ref=e1115]
                    - cell "effc14e7-ae82-499b-9034-f4b57009f8c2" [ref=e1116]:
                      - code [ref=e1119]: effc14e7-ae82-499b-9034-f4b57009f8c2
                  - row "originalFilename knowledge-upload.pdf" [ref=e1120]:
                    - rowheader "originalFilename" [ref=e1121]
                    - cell "knowledge-upload.pdf" [ref=e1122]
                  - row "status COMPLETED" [ref=e1123]:
                    - rowheader "status" [ref=e1124]
                    - cell "COMPLETED" [ref=e1125]:
                      - generic [ref=e1127]: COMPLETED
                  - row "totalChunks 1" [ref=e1128]:
                    - rowheader "totalChunks" [ref=e1129]
                    - cell "1" [ref=e1130]
                  - row "createdAt 4/25/2026, 2:38:15 AM" [ref=e1131]:
                    - rowheader "createdAt" [ref=e1132]
                    - cell "4/25/2026, 2:38:15 AM" [ref=e1133]
                  - row "updatedAt 4/25/2026, 2:38:25 AM" [ref=e1134]:
                    - rowheader "updatedAt" [ref=e1135]
                    - cell "4/25/2026, 2:38:25 AM" [ref=e1136]
                  - row "retryable false" [ref=e1137]:
                    - rowheader "retryable" [ref=e1138]
                    - cell "false" [ref=e1139]
              - generic [ref=e1141]:
                - generic [ref=e1144]: Error / operator notes
                - generic [ref=e1146]: 当前 job 没有 errorMessage。
```

# Test source

```ts
  199 |       apiTraffic.stop();
  200 |       ingestionReads.stop();
  201 |     }
  202 |   });
  203 | 
  204 |   test('keeps sub-surface visibility scoped to the admin capability actually granted and forbids deep-link mutations', async ({
  205 |     page,
  206 |     request,
  207 |   }) => {
  208 |     const suffix = uniqueSuffix();
  209 |     const failedJobId = seedFailedIngestionJobFixture(suffix);
  210 |     const seededContradiction = seedKnowledgeGraphFixture(`readonly-${suffix}`);
  211 |     const ragReader = await createAdminWithPermissions(request, ['rag:read'], 'RAG Reader Only');
  212 |     const kgReader = await createAdminWithPermissions(request, ['kg:read'], 'KG Reader Only');
  213 | 
  214 |     const ragReaderSession = await loginViaAdminApi(request, ragReader.username, ragReader.password);
  215 |     const ragRetryResponse = await request.post(`${adminApiBaseUrl}/api/admin/knowledge/ingestion/jobs/${failedJobId}/retry`, {
  216 |       headers: {
  217 |         Authorization: `Bearer ${ragReaderSession.accessToken}`,
  218 |       },
  219 |     });
  220 |     expect(ragRetryResponse.status()).toBe(403);
  221 |     expect(((await ragRetryResponse.json()) as { code: string }).code).toBe('forbidden');
  222 | 
  223 |     await loginViaUi(page, ragReader.username, ragReader.password);
  224 |     await page.goto(`/knowledge-ops?view=kg-review&status=FAILED&selected=${encodeURIComponent(failedJobId)}`);
  225 | 
  226 |     await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
  227 |     await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
  228 |     await expect(page.getByTestId('knowledge-contradiction-list')).toHaveCount(0);
  229 |     await expect(page.getByTestId('knowledge-ingestion-readonly-note')).toBeVisible();
  230 |     await expect(page.getByTestId('knowledge-upload-submit')).toHaveCount(0);
  231 |     await expect(page.getByTestId('knowledge-retry-job')).toHaveCount(0);
  232 |     await expect(page.getByTestId('knowledge-ingestion-status')).toContainText('FAILED');
  233 | 
  234 |     const kgReaderSession = await loginViaAdminApi(request, kgReader.username, kgReader.password);
  235 |     const kgResolveResponse = await request.patch(
  236 |       `${adminApiBaseUrl}/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/resolve`,
  237 |       {
  238 |         headers: {
  239 |           Authorization: `Bearer ${kgReaderSession.accessToken}`,
  240 |           'Content-Type': 'application/json',
  241 |         },
  242 |         data: {
  243 |           adminNotes: 'forbidden_write',
  244 |         },
  245 |       },
  246 |     );
  247 |     expect(kgResolveResponse.status()).toBe(403);
  248 |     expect(((await kgResolveResponse.json()) as { code: string }).code).toBe('forbidden');
  249 | 
  250 |     await loginViaUi(page, kgReader.username, kgReader.password);
  251 |     await page.goto(
  252 |       `/knowledge-ops?view=ingestion&status=escalated&selected=${encodeURIComponent(seededContradiction.contradictionId)}`,
  253 |     );
  254 | 
  255 |     await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
  256 |     await expect(page.getByTestId('knowledge-ingestion-queue')).toHaveCount(0);
  257 |     await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
  258 |     await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
  259 |     await expect(page.getByTestId('knowledge-kg-readonly-note')).toBeVisible();
  260 |     await expect(page.getByTestId('knowledge-kg-status')).toContainText('escalated');
  261 |     await expect(page.getByTestId('knowledge-resolve-submit')).toBeDisabled();
  262 |     await expect(page.getByTestId(`knowledge-notification-read-${seededContradiction.notificationId}`)).toHaveCount(0);
  263 |   });
  264 | });
  265 | 
  266 | async function loginViaUi(page: Page, username: string = 'super_admin', password: string = 'SuperAdmin123!') {
  267 |   await page.goto('/login');
  268 |   await page.evaluate((storageKey) => window.localStorage.removeItem(storageKey), sessionStorageKey);
  269 |   await page.goto('/login');
  270 | 
  271 |   const loginResponse = page.waitForResponse(
  272 |     (response) => exactApiPath(response, '/api/admin/auth/login') && response.request().method() === 'POST',
  273 |   );
  274 |   const meResponse = page.waitForResponse(
  275 |     (response) => exactApiPath(response, '/api/admin/me') && response.request().method() === 'GET',
  276 |   );
  277 | 
  278 |   await page.getByLabel('用户名').fill(username);
  279 |   await page.getByLabel('密码').fill(password);
  280 |   await page.getByTestId('login-submit').click();
  281 | 
  282 |   expect((await loginResponse).status()).toBe(200);
  283 |   expect((await meResponse).status()).toBe(200);
  284 |   await expect(page).toHaveURL(/\/overview$|\/users$|\/knowledge-ops(?:\?.*)?$|\/mentor\/audits$|\/distribution\/stats(?:\?.*)?$/);
  285 |   await expect(page.getByTestId('protected-shell')).toBeVisible();
  286 | }
  287 | 
  288 | async function expectIngestionReadsToSettle(
  289 |   page: Page,
  290 |   tracker: { events: Array<{ path: string; status: number; method: string }> },
  291 |   baselineCount: number,
  292 | ) {
  293 |   await page.waitForTimeout(POLL_SETTLE_WAIT_MS);
  294 |   const afterFirstWindow = tracker.events.length;
  295 |   expect(afterFirstWindow).toBeGreaterThanOrEqual(baselineCount);
  296 |   expect(afterFirstWindow - baselineCount).toBeLessThanOrEqual(2);
  297 | 
  298 |   await page.waitForTimeout(POLL_SETTLE_WAIT_MS);
> 299 |   expect(tracker.events.length).toBe(afterFirstWindow);
      |                                 ^ Error: expect(received).toBe(expected) // Object.is equality
  300 | }
  301 | 
  302 | function trackResponses(page: Page, matcher: (response: Response) => boolean) {
  303 |   const events: Array<{ path: string; status: number; method: string }> = [];
  304 |   const listener = (response: Response) => {
  305 |     if (!matcher(response)) {
  306 |       return;
  307 |     }
  308 | 
  309 |     const request = response.request();
  310 |     events.push({
  311 |       path: new URL(response.url()).pathname,
  312 |       status: response.status(),
  313 |       method: request.method(),
  314 |     });
  315 |   };
  316 | 
  317 |   page.on('response', listener);
  318 | 
  319 |   return {
  320 |     events,
  321 |     stop: () => page.off('response', listener),
  322 |   };
  323 | }
  324 | 
  325 | function exactApiPath(response: Response, pathname: string): boolean {
  326 |   return new URL(response.url()).pathname === pathname;
  327 | }
  328 | 
  329 | function uniqueSuffix(): string {
  330 |   return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  331 | }
  332 | 
```
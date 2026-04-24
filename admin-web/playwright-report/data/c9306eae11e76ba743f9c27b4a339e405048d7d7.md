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

Expected: 11
Received: 13
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
              - generic [ref=e159]: "access token expires at: 2026-04-24T19:29:09.489906745Z"
              - generic [ref=e161]: "refresh token expires at: 2026-05-01T19:14:09.490551353Z"
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
              - generic [ref=e194]: "access expires: 4/25/2026, 3:29:09 AM"
            - generic [ref=e196]:
              - generic [ref=e198]: "view: ingestion"
              - generic [ref=e200]: "status: all"
              - generic [ref=e202]: "selected: efd53785-7fd7-43bf-ae87-aac47392c40a"
              - generic [ref=e204]: "queue freshness: polling 6"
              - generic [ref=e206]: "updatedAt: 4/25/2026, 3:14:31 AM"
            - code [ref=e209]: view=ingestion&status=all&selected=efd53785-7fd7-43bf-ae87-aac47392c40a
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
              - generic [ref=e238]: "poll: 6/8"
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
                - generic [ref=e291]: jobId=efd53785-7fd7-43bf-ae87-aac47392c40a; status=COMPLETED; totalChunks=1; updatedAt=4/25/2026, 3:14:20 AM
        - generic [ref=e293]:
          - generic [ref=e294]:
            - generic [ref=e297]: Ingestion jobs (20)
            - list [ref=e302]:
              - listitem [ref=e303]:
                - generic [ref=e304]:
                  - generic [ref=e306]:
                    - generic [ref=e308]:
                      - code [ref=e311]: efd53785-7fd7-43bf-ae87-aac47392c40a
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
                      - 'row "updatedAt : 4/25/2026, 3:14:20 AM" [ref=e332]':
                        - 'cell "updatedAt : 4/25/2026, 3:14:20 AM" [ref=e333]':
                          - generic [ref=e334]:
                            - generic [ref=e335]: "updatedAt :"
                            - generic [ref=e336]: 4/25/2026, 3:14:20 AM
                      - 'row "errorMessage : —" [ref=e337]':
                        - 'cell "errorMessage : —" [ref=e338]':
                          - generic [ref=e339]:
                            - generic [ref=e340]: "errorMessage :"
                            - generic [ref=e341]: —
              - listitem [ref=e342]:
                - generic [ref=e343]:
                  - generic [ref=e345]:
                    - generic [ref=e347]:
                      - code [ref=e350]: 6cdb052f-e4b8-40b2-8306-35071778ccac
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
                      - 'row "updatedAt : 4/25/2026, 2:52:15 AM" [ref=e371]':
                        - 'cell "updatedAt : 4/25/2026, 2:52:15 AM" [ref=e372]':
                          - generic [ref=e373]:
                            - generic [ref=e374]: "updatedAt :"
                            - generic [ref=e375]: 4/25/2026, 2:52:15 AM
                      - 'row "errorMessage : —" [ref=e376]':
                        - 'cell "errorMessage : —" [ref=e377]':
                          - generic [ref=e378]:
                            - generic [ref=e379]: "errorMessage :"
                            - generic [ref=e380]: —
              - listitem [ref=e381]:
                - generic [ref=e382]:
                  - generic [ref=e384]:
                    - generic [ref=e386]:
                      - code [ref=e389]: 182a4706-c4d9-4775-94ec-a1ea3f8b4455
                      - generic [ref=e391]: FAILED
                      - generic [ref=e393]: retryable
                    - button "查看详情" [ref=e395] [cursor=pointer]:
                      - generic [ref=e396]: 查看详情
                  - table [ref=e400]:
                    - rowgroup [ref=e401]:
                      - 'row "filename : forced-mod9pro8h01wxy.pdf" [ref=e402]':
                        - 'cell "filename : forced-mod9pro8h01wxy.pdf" [ref=e403]':
                          - generic [ref=e404]:
                            - generic [ref=e405]: "filename :"
                            - generic [ref=e406]: forced-mod9pro8h01wxy.pdf
                      - 'row "totalChunks : 0" [ref=e407]':
                        - 'cell "totalChunks : 0" [ref=e408]':
                          - generic [ref=e409]:
                            - generic [ref=e410]: "totalChunks :"
                            - generic [ref=e411]: "0"
                      - 'row "updatedAt : 4/25/2026, 2:51:47 AM" [ref=e412]':
                        - 'cell "updatedAt : 4/25/2026, 2:51:47 AM" [ref=e413]':
                          - generic [ref=e414]:
                            - generic [ref=e415]: "updatedAt :"
                            - generic [ref=e416]: 4/25/2026, 2:51:47 AM
                      - 'row "errorMessage : forced failure mod9pro8h01wxy" [ref=e417]':
                        - 'cell "errorMessage : forced failure mod9pro8h01wxy" [ref=e418]':
                          - generic [ref=e419]:
                            - generic [ref=e420]: "errorMessage :"
                            - generic [ref=e421]: forced failure mod9pro8h01wxy
              - listitem [ref=e422]:
                - generic [ref=e423]:
                  - generic [ref=e425]:
                    - generic [ref=e427]:
                      - code [ref=e430]: effc14e7-ae82-499b-9034-f4b57009f8c2
                      - generic [ref=e432]: COMPLETED
                    - button "查看详情" [ref=e434] [cursor=pointer]:
                      - generic [ref=e435]: 查看详情
                  - table [ref=e439]:
                    - rowgroup [ref=e440]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e441]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e442]':
                          - generic [ref=e443]:
                            - generic [ref=e444]: "filename :"
                            - generic [ref=e445]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e446]':
                        - 'cell "totalChunks : 1" [ref=e447]':
                          - generic [ref=e448]:
                            - generic [ref=e449]: "totalChunks :"
                            - generic [ref=e450]: "1"
                      - 'row "updatedAt : 4/25/2026, 2:38:25 AM" [ref=e451]':
                        - 'cell "updatedAt : 4/25/2026, 2:38:25 AM" [ref=e452]':
                          - generic [ref=e453]:
                            - generic [ref=e454]: "updatedAt :"
                            - generic [ref=e455]: 4/25/2026, 2:38:25 AM
                      - 'row "errorMessage : —" [ref=e456]':
                        - 'cell "errorMessage : —" [ref=e457]':
                          - generic [ref=e458]:
                            - generic [ref=e459]: "errorMessage :"
                            - generic [ref=e460]: —
              - listitem [ref=e461]:
                - generic [ref=e462]:
                  - generic [ref=e464]:
                    - generic [ref=e466]:
                      - code [ref=e469]: 5ff8d71b-79e5-46b7-8dc3-337e37323b37
                      - generic [ref=e471]: FAILED
                      - generic [ref=e473]: retryable
                    - button "查看详情" [ref=e475] [cursor=pointer]:
                      - generic [ref=e476]: 查看详情
                  - table [ref=e480]:
                    - rowgroup [ref=e481]:
                      - 'row "filename : forced-mod98dx83lamje.pdf" [ref=e482]':
                        - 'cell "filename : forced-mod98dx83lamje.pdf" [ref=e483]':
                          - generic [ref=e484]:
                            - generic [ref=e485]: "filename :"
                            - generic [ref=e486]: forced-mod98dx83lamje.pdf
                      - 'row "totalChunks : 0" [ref=e487]':
                        - 'cell "totalChunks : 0" [ref=e488]':
                          - generic [ref=e489]:
                            - generic [ref=e490]: "totalChunks :"
                            - generic [ref=e491]: "0"
                      - 'row "updatedAt : 4/25/2026, 2:38:14 AM" [ref=e492]':
                        - 'cell "updatedAt : 4/25/2026, 2:38:14 AM" [ref=e493]':
                          - generic [ref=e494]:
                            - generic [ref=e495]: "updatedAt :"
                            - generic [ref=e496]: 4/25/2026, 2:38:14 AM
                      - 'row "errorMessage : forced failure mod98dx83lamje" [ref=e497]':
                        - 'cell "errorMessage : forced failure mod98dx83lamje" [ref=e498]':
                          - generic [ref=e499]:
                            - generic [ref=e500]: "errorMessage :"
                            - generic [ref=e501]: forced failure mod98dx83lamje
              - listitem [ref=e502]:
                - generic [ref=e503]:
                  - generic [ref=e505]:
                    - generic [ref=e507]:
                      - code [ref=e510]: 6c232c9d-c3ff-4e63-827e-75fcd97d1564
                      - generic [ref=e512]: COMPLETED
                    - button "查看详情" [ref=e514] [cursor=pointer]:
                      - generic [ref=e515]: 查看详情
                  - table [ref=e519]:
                    - rowgroup [ref=e520]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e521]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e522]':
                          - generic [ref=e523]:
                            - generic [ref=e524]: "filename :"
                            - generic [ref=e525]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e526]':
                        - 'cell "totalChunks : 1" [ref=e527]':
                          - generic [ref=e528]:
                            - generic [ref=e529]: "totalChunks :"
                            - generic [ref=e530]: "1"
                      - 'row "updatedAt : 4/25/2026, 12:06:43 AM" [ref=e531]':
                        - 'cell "updatedAt : 4/25/2026, 12:06:43 AM" [ref=e532]':
                          - generic [ref=e533]:
                            - generic [ref=e534]: "updatedAt :"
                            - generic [ref=e535]: 4/25/2026, 12:06:43 AM
                      - 'row "errorMessage : —" [ref=e536]':
                        - 'cell "errorMessage : —" [ref=e537]':
                          - generic [ref=e538]:
                            - generic [ref=e539]: "errorMessage :"
                            - generic [ref=e540]: —
              - listitem [ref=e541]:
                - generic [ref=e542]:
                  - generic [ref=e544]:
                    - generic [ref=e546]:
                      - code [ref=e549]: ebe5861e-c98a-4c8d-8d50-7c14b12ab865
                      - generic [ref=e551]: FAILED
                      - generic [ref=e553]: retryable
                    - button "查看详情" [ref=e555] [cursor=pointer]:
                      - generic [ref=e556]: 查看详情
                  - table [ref=e560]:
                    - rowgroup [ref=e561]:
                      - 'row "filename : forced-mod3swm93dto4j.pdf" [ref=e562]':
                        - 'cell "filename : forced-mod3swm93dto4j.pdf" [ref=e563]':
                          - generic [ref=e564]:
                            - generic [ref=e565]: "filename :"
                            - generic [ref=e566]: forced-mod3swm93dto4j.pdf
                      - 'row "totalChunks : 0" [ref=e567]':
                        - 'cell "totalChunks : 0" [ref=e568]':
                          - generic [ref=e569]:
                            - generic [ref=e570]: "totalChunks :"
                            - generic [ref=e571]: "0"
                      - 'row "updatedAt : 4/25/2026, 12:06:16 AM" [ref=e572]':
                        - 'cell "updatedAt : 4/25/2026, 12:06:16 AM" [ref=e573]':
                          - generic [ref=e574]:
                            - generic [ref=e575]: "updatedAt :"
                            - generic [ref=e576]: 4/25/2026, 12:06:16 AM
                      - 'row "errorMessage : forced failure mod3swm93dto4j" [ref=e577]':
                        - 'cell "errorMessage : forced failure mod3swm93dto4j" [ref=e578]':
                          - generic [ref=e579]:
                            - generic [ref=e580]: "errorMessage :"
                            - generic [ref=e581]: forced failure mod3swm93dto4j
              - listitem [ref=e582]:
                - generic [ref=e583]:
                  - generic [ref=e585]:
                    - generic [ref=e587]:
                      - code [ref=e590]: a9d8d709-b190-4f46-b740-e59ee7fcae45
                      - generic [ref=e592]: PENDING
                    - button "查看详情" [ref=e594] [cursor=pointer]:
                      - generic [ref=e595]: 查看详情
                  - table [ref=e599]:
                    - rowgroup [ref=e600]:
                      - 'row "filename : stale-fixture.pdf" [ref=e601]':
                        - 'cell "filename : stale-fixture.pdf" [ref=e602]':
                          - generic [ref=e603]:
                            - generic [ref=e604]: "filename :"
                            - generic [ref=e605]: stale-fixture.pdf
                      - 'row "totalChunks : 0" [ref=e606]':
                        - 'cell "totalChunks : 0" [ref=e607]':
                          - generic [ref=e608]:
                            - generic [ref=e609]: "totalChunks :"
                            - generic [ref=e610]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:25:40 PM" [ref=e611]':
                        - 'cell "updatedAt : 4/24/2026, 10:25:40 PM" [ref=e612]':
                          - generic [ref=e613]:
                            - generic [ref=e614]: "updatedAt :"
                            - generic [ref=e615]: 4/24/2026, 10:25:40 PM
                      - 'row "errorMessage : —" [ref=e616]':
                        - 'cell "errorMessage : —" [ref=e617]':
                          - generic [ref=e618]:
                            - generic [ref=e619]: "errorMessage :"
                            - generic [ref=e620]: —
              - listitem [ref=e621]:
                - generic [ref=e622]:
                  - generic [ref=e624]:
                    - generic [ref=e626]:
                      - code [ref=e629]: b325b280-875e-41c7-860a-42261613dfbf
                      - generic [ref=e631]: COMPLETED
                    - button "查看详情" [ref=e633] [cursor=pointer]:
                      - generic [ref=e634]: 查看详情
                  - table [ref=e638]:
                    - rowgroup [ref=e639]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e640]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e641]':
                          - generic [ref=e642]:
                            - generic [ref=e643]: "filename :"
                            - generic [ref=e644]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e645]':
                        - 'cell "totalChunks : 1" [ref=e646]':
                          - generic [ref=e647]:
                            - generic [ref=e648]: "totalChunks :"
                            - generic [ref=e649]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:23:03 PM" [ref=e650]':
                        - 'cell "updatedAt : 4/24/2026, 10:23:03 PM" [ref=e651]':
                          - generic [ref=e652]:
                            - generic [ref=e653]: "updatedAt :"
                            - generic [ref=e654]: 4/24/2026, 10:23:03 PM
                      - 'row "errorMessage : —" [ref=e655]':
                        - 'cell "errorMessage : —" [ref=e656]':
                          - generic [ref=e657]:
                            - generic [ref=e658]: "errorMessage :"
                            - generic [ref=e659]: —
              - listitem [ref=e660]:
                - generic [ref=e661]:
                  - generic [ref=e663]:
                    - generic [ref=e665]:
                      - code [ref=e668]: 7f55ae1a-f724-4dc6-876c-7cd6f5b66b5e
                      - generic [ref=e670]: COMPLETED
                    - button "查看详情" [ref=e672] [cursor=pointer]:
                      - generic [ref=e673]: 查看详情
                  - table [ref=e677]:
                    - rowgroup [ref=e678]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e679]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e680]':
                          - generic [ref=e681]:
                            - generic [ref=e682]: "filename :"
                            - generic [ref=e683]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e684]':
                        - 'cell "totalChunks : 1" [ref=e685]':
                          - generic [ref=e686]:
                            - generic [ref=e687]: "totalChunks :"
                            - generic [ref=e688]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:22:51 PM" [ref=e689]':
                        - 'cell "updatedAt : 4/24/2026, 10:22:51 PM" [ref=e690]':
                          - generic [ref=e691]:
                            - generic [ref=e692]: "updatedAt :"
                            - generic [ref=e693]: 4/24/2026, 10:22:51 PM
                      - 'row "errorMessage : —" [ref=e694]':
                        - 'cell "errorMessage : —" [ref=e695]':
                          - generic [ref=e696]:
                            - generic [ref=e697]: "errorMessage :"
                            - generic [ref=e698]: —
              - listitem [ref=e699]:
                - generic [ref=e700]:
                  - generic [ref=e702]:
                    - generic [ref=e704]:
                      - code [ref=e707]: f08eda3e-bcc5-4ee1-b3e8-6839acf8d17e
                      - generic [ref=e709]: FAILED
                      - generic [ref=e711]: retryable
                    - button "查看详情" [ref=e713] [cursor=pointer]:
                      - generic [ref=e714]: 查看详情
                  - table [ref=e718]:
                    - rowgroup [ref=e719]:
                      - 'row "filename : forced-mod034532seswx.pdf" [ref=e720]':
                        - 'cell "filename : forced-mod034532seswx.pdf" [ref=e721]':
                          - generic [ref=e722]:
                            - generic [ref=e723]: "filename :"
                            - generic [ref=e724]: forced-mod034532seswx.pdf
                      - 'row "totalChunks : 0" [ref=e725]':
                        - 'cell "totalChunks : 0" [ref=e726]':
                          - generic [ref=e727]:
                            - generic [ref=e728]: "totalChunks :"
                            - generic [ref=e729]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:22:12 PM" [ref=e730]':
                        - 'cell "updatedAt : 4/24/2026, 10:22:12 PM" [ref=e731]':
                          - generic [ref=e732]:
                            - generic [ref=e733]: "updatedAt :"
                            - generic [ref=e734]: 4/24/2026, 10:22:12 PM
                      - 'row "errorMessage : forced failure mod034532seswx" [ref=e735]':
                        - 'cell "errorMessage : forced failure mod034532seswx" [ref=e736]':
                          - generic [ref=e737]:
                            - generic [ref=e738]: "errorMessage :"
                            - generic [ref=e739]: forced failure mod034532seswx
              - listitem [ref=e740]:
                - generic [ref=e741]:
                  - generic [ref=e743]:
                    - generic [ref=e745]:
                      - code [ref=e748]: d59b3f70-f243-464f-a34e-509d58dadd84
                      - generic [ref=e750]: COMPLETED
                    - button "查看详情" [ref=e752] [cursor=pointer]:
                      - generic [ref=e753]: 查看详情
                  - table [ref=e757]:
                    - rowgroup [ref=e758]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e759]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e760]':
                          - generic [ref=e761]:
                            - generic [ref=e762]: "filename :"
                            - generic [ref=e763]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e764]':
                        - 'cell "totalChunks : 1" [ref=e765]':
                          - generic [ref=e766]:
                            - generic [ref=e767]: "totalChunks :"
                            - generic [ref=e768]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:07:03 PM" [ref=e769]':
                        - 'cell "updatedAt : 4/24/2026, 10:07:03 PM" [ref=e770]':
                          - generic [ref=e771]:
                            - generic [ref=e772]: "updatedAt :"
                            - generic [ref=e773]: 4/24/2026, 10:07:03 PM
                      - 'row "errorMessage : —" [ref=e774]':
                        - 'cell "errorMessage : —" [ref=e775]':
                          - generic [ref=e776]:
                            - generic [ref=e777]: "errorMessage :"
                            - generic [ref=e778]: —
              - listitem [ref=e779]:
                - generic [ref=e780]:
                  - generic [ref=e782]:
                    - generic [ref=e784]:
                      - code [ref=e787]: badc28c9-0423-4491-ad2a-3a802571697d
                      - generic [ref=e789]: COMPLETED
                    - button "查看详情" [ref=e791] [cursor=pointer]:
                      - generic [ref=e792]: 查看详情
                  - table [ref=e796]:
                    - rowgroup [ref=e797]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e798]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e799]':
                          - generic [ref=e800]:
                            - generic [ref=e801]: "filename :"
                            - generic [ref=e802]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e803]':
                        - 'cell "totalChunks : 1" [ref=e804]':
                          - generic [ref=e805]:
                            - generic [ref=e806]: "totalChunks :"
                            - generic [ref=e807]: "1"
                      - 'row "updatedAt : 4/24/2026, 10:06:48 PM" [ref=e808]':
                        - 'cell "updatedAt : 4/24/2026, 10:06:48 PM" [ref=e809]':
                          - generic [ref=e810]:
                            - generic [ref=e811]: "updatedAt :"
                            - generic [ref=e812]: 4/24/2026, 10:06:48 PM
                      - 'row "errorMessage : —" [ref=e813]':
                        - 'cell "errorMessage : —" [ref=e814]':
                          - generic [ref=e815]:
                            - generic [ref=e816]: "errorMessage :"
                            - generic [ref=e817]: —
              - listitem [ref=e818]:
                - generic [ref=e819]:
                  - generic [ref=e821]:
                    - generic [ref=e823]:
                      - code [ref=e826]: 0a87fb99-292d-485e-b559-5b044ea67c27
                      - generic [ref=e828]: FAILED
                      - generic [ref=e830]: retryable
                    - button "查看详情" [ref=e832] [cursor=pointer]:
                      - generic [ref=e833]: 查看详情
                  - table [ref=e837]:
                    - rowgroup [ref=e838]:
                      - 'row "filename : forced-moczijmv3hmhet.pdf" [ref=e839]':
                        - 'cell "filename : forced-moczijmv3hmhet.pdf" [ref=e840]':
                          - generic [ref=e841]:
                            - generic [ref=e842]: "filename :"
                            - generic [ref=e843]: forced-moczijmv3hmhet.pdf
                      - 'row "totalChunks : 0" [ref=e844]':
                        - 'cell "totalChunks : 0" [ref=e845]':
                          - generic [ref=e846]:
                            - generic [ref=e847]: "totalChunks :"
                            - generic [ref=e848]: "0"
                      - 'row "updatedAt : 4/24/2026, 10:06:12 PM" [ref=e849]':
                        - 'cell "updatedAt : 4/24/2026, 10:06:12 PM" [ref=e850]':
                          - generic [ref=e851]:
                            - generic [ref=e852]: "updatedAt :"
                            - generic [ref=e853]: 4/24/2026, 10:06:12 PM
                      - 'row "errorMessage : forced failure moczijmv3hmhet" [ref=e854]':
                        - 'cell "errorMessage : forced failure moczijmv3hmhet" [ref=e855]':
                          - generic [ref=e856]:
                            - generic [ref=e857]: "errorMessage :"
                            - generic [ref=e858]: forced failure moczijmv3hmhet
              - listitem [ref=e859]:
                - generic [ref=e860]:
                  - generic [ref=e862]:
                    - generic [ref=e864]:
                      - code [ref=e867]: 61161aeb-1b33-4aeb-92be-32ad5e24234b
                      - generic [ref=e869]: COMPLETED
                    - button "查看详情" [ref=e871] [cursor=pointer]:
                      - generic [ref=e872]: 查看详情
                  - table [ref=e876]:
                    - rowgroup [ref=e877]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e878]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e879]':
                          - generic [ref=e880]:
                            - generic [ref=e881]: "filename :"
                            - generic [ref=e882]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e883]':
                        - 'cell "totalChunks : 1" [ref=e884]':
                          - generic [ref=e885]:
                            - generic [ref=e886]: "totalChunks :"
                            - generic [ref=e887]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:59:20 PM" [ref=e888]':
                        - 'cell "updatedAt : 4/24/2026, 9:59:20 PM" [ref=e889]':
                          - generic [ref=e890]:
                            - generic [ref=e891]: "updatedAt :"
                            - generic [ref=e892]: 4/24/2026, 9:59:20 PM
                      - 'row "errorMessage : —" [ref=e893]':
                        - 'cell "errorMessage : —" [ref=e894]':
                          - generic [ref=e895]:
                            - generic [ref=e896]: "errorMessage :"
                            - generic [ref=e897]: —
              - listitem [ref=e898]:
                - generic [ref=e899]:
                  - generic [ref=e901]:
                    - generic [ref=e903]:
                      - code [ref=e906]: bef6223f-0f02-4f1a-b1c0-4c850f09324a
                      - generic [ref=e908]: COMPLETED
                    - button "查看详情" [ref=e910] [cursor=pointer]:
                      - generic [ref=e911]: 查看详情
                  - table [ref=e915]:
                    - rowgroup [ref=e916]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e917]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e918]':
                          - generic [ref=e919]:
                            - generic [ref=e920]: "filename :"
                            - generic [ref=e921]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e922]':
                        - 'cell "totalChunks : 1" [ref=e923]':
                          - generic [ref=e924]:
                            - generic [ref=e925]: "totalChunks :"
                            - generic [ref=e926]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:59:13 PM" [ref=e927]':
                        - 'cell "updatedAt : 4/24/2026, 9:59:13 PM" [ref=e928]':
                          - generic [ref=e929]:
                            - generic [ref=e930]: "updatedAt :"
                            - generic [ref=e931]: 4/24/2026, 9:59:13 PM
                      - 'row "errorMessage : —" [ref=e932]':
                        - 'cell "errorMessage : —" [ref=e933]':
                          - generic [ref=e934]:
                            - generic [ref=e935]: "errorMessage :"
                            - generic [ref=e936]: —
              - listitem [ref=e937]:
                - generic [ref=e938]:
                  - generic [ref=e940]:
                    - generic [ref=e942]:
                      - code [ref=e945]: 022a2f15-e134-4fd9-a9f3-de4726b2d449
                      - generic [ref=e947]: FAILED
                      - generic [ref=e949]: retryable
                    - button "查看详情" [ref=e951] [cursor=pointer]:
                      - generic [ref=e952]: 查看详情
                  - table [ref=e956]:
                    - rowgroup [ref=e957]:
                      - 'row "filename : forced-mocz8kspbuwlie.pdf" [ref=e958]':
                        - 'cell "filename : forced-mocz8kspbuwlie.pdf" [ref=e959]':
                          - generic [ref=e960]:
                            - generic [ref=e961]: "filename :"
                            - generic [ref=e962]: forced-mocz8kspbuwlie.pdf
                      - 'row "totalChunks : 0" [ref=e963]':
                        - 'cell "totalChunks : 0" [ref=e964]':
                          - generic [ref=e965]:
                            - generic [ref=e966]: "totalChunks :"
                            - generic [ref=e967]: "0"
                      - 'row "updatedAt : 4/24/2026, 9:58:27 PM" [ref=e968]':
                        - 'cell "updatedAt : 4/24/2026, 9:58:27 PM" [ref=e969]':
                          - generic [ref=e970]:
                            - generic [ref=e971]: "updatedAt :"
                            - generic [ref=e972]: 4/24/2026, 9:58:27 PM
                      - 'row "errorMessage : forced failure mocz8kspbuwlie" [ref=e973]':
                        - 'cell "errorMessage : forced failure mocz8kspbuwlie" [ref=e974]':
                          - generic [ref=e975]:
                            - generic [ref=e976]: "errorMessage :"
                            - generic [ref=e977]: forced failure mocz8kspbuwlie
              - listitem [ref=e978]:
                - generic [ref=e979]:
                  - generic [ref=e981]:
                    - generic [ref=e983]:
                      - code [ref=e986]: 7a0fcbaa-aecf-4bce-99c8-65d4dddb9627
                      - generic [ref=e988]: COMPLETED
                    - button "查看详情" [ref=e990] [cursor=pointer]:
                      - generic [ref=e991]: 查看详情
                  - table [ref=e995]:
                    - rowgroup [ref=e996]:
                      - 'row "filename : knowledge-bad.pdf" [ref=e997]':
                        - 'cell "filename : knowledge-bad.pdf" [ref=e998]':
                          - generic [ref=e999]:
                            - generic [ref=e1000]: "filename :"
                            - generic [ref=e1001]: knowledge-bad.pdf
                      - 'row "totalChunks : 1" [ref=e1002]':
                        - 'cell "totalChunks : 1" [ref=e1003]':
                          - generic [ref=e1004]:
                            - generic [ref=e1005]: "totalChunks :"
                            - generic [ref=e1006]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:52:27 PM" [ref=e1007]':
                        - 'cell "updatedAt : 4/24/2026, 9:52:27 PM" [ref=e1008]':
                          - generic [ref=e1009]:
                            - generic [ref=e1010]: "updatedAt :"
                            - generic [ref=e1011]: 4/24/2026, 9:52:27 PM
                      - 'row "errorMessage : —" [ref=e1012]':
                        - 'cell "errorMessage : —" [ref=e1013]':
                          - generic [ref=e1014]:
                            - generic [ref=e1015]: "errorMessage :"
                            - generic [ref=e1016]: —
              - listitem [ref=e1017]:
                - generic [ref=e1018]:
                  - generic [ref=e1020]:
                    - generic [ref=e1022]:
                      - code [ref=e1025]: 4460c0d6-efdf-4aa9-a6f4-908340f2f724
                      - generic [ref=e1027]: COMPLETED
                    - button "查看详情" [ref=e1029] [cursor=pointer]:
                      - generic [ref=e1030]: 查看详情
                  - table [ref=e1034]:
                    - rowgroup [ref=e1035]:
                      - 'row "filename : knowledge-upload.pdf" [ref=e1036]':
                        - 'cell "filename : knowledge-upload.pdf" [ref=e1037]':
                          - generic [ref=e1038]:
                            - generic [ref=e1039]: "filename :"
                            - generic [ref=e1040]: knowledge-upload.pdf
                      - 'row "totalChunks : 1" [ref=e1041]':
                        - 'cell "totalChunks : 1" [ref=e1042]':
                          - generic [ref=e1043]:
                            - generic [ref=e1044]: "totalChunks :"
                            - generic [ref=e1045]: "1"
                      - 'row "updatedAt : 4/24/2026, 9:52:19 PM" [ref=e1046]':
                        - 'cell "updatedAt : 4/24/2026, 9:52:19 PM" [ref=e1047]':
                          - generic [ref=e1048]:
                            - generic [ref=e1049]: "updatedAt :"
                            - generic [ref=e1050]: 4/24/2026, 9:52:19 PM
                      - 'row "errorMessage : —" [ref=e1051]':
                        - 'cell "errorMessage : —" [ref=e1052]':
                          - generic [ref=e1053]:
                            - generic [ref=e1054]: "errorMessage :"
                            - generic [ref=e1055]: —
              - listitem [ref=e1056]:
                - generic [ref=e1057]:
                  - generic [ref=e1059]:
                    - generic [ref=e1061]:
                      - code [ref=e1064]: 543a906b-60e3-4ea9-ba7f-69216934855e
                      - generic [ref=e1066]: FAILED
                      - generic [ref=e1068]: retryable
                    - button "查看详情" [ref=e1070] [cursor=pointer]:
                      - generic [ref=e1071]: 查看详情
                  - table [ref=e1075]:
                    - rowgroup [ref=e1076]:
                      - 'row "filename : forced-mocyzoi5fdkw57.pdf" [ref=e1077]':
                        - 'cell "filename : forced-mocyzoi5fdkw57.pdf" [ref=e1078]':
                          - generic [ref=e1079]:
                            - generic [ref=e1080]: "filename :"
                            - generic [ref=e1081]: forced-mocyzoi5fdkw57.pdf
                      - 'row "totalChunks : 0" [ref=e1082]':
                        - 'cell "totalChunks : 0" [ref=e1083]':
                          - generic [ref=e1084]:
                            - generic [ref=e1085]: "totalChunks :"
                            - generic [ref=e1086]: "0"
                      - 'row "updatedAt : 4/24/2026, 9:51:32 PM" [ref=e1087]':
                        - 'cell "updatedAt : 4/24/2026, 9:51:32 PM" [ref=e1088]':
                          - generic [ref=e1089]:
                            - generic [ref=e1090]: "updatedAt :"
                            - generic [ref=e1091]: 4/24/2026, 9:51:32 PM
                      - 'row "errorMessage : forced failure mocyzoi5fdkw57" [ref=e1092]':
                        - 'cell "errorMessage : forced failure mocyzoi5fdkw57" [ref=e1093]':
                          - generic [ref=e1094]:
                            - generic [ref=e1095]: "errorMessage :"
                            - generic [ref=e1096]: forced failure mocyzoi5fdkw57
          - generic [ref=e1097]:
            - generic [ref=e1099]:
              - generic [ref=e1100]: Ingestion detail · efd53785-7fd7-43bf-ae87-aac47392c40a
              - generic [ref=e1102]:
                - button "关闭详情" [ref=e1104] [cursor=pointer]:
                  - generic [ref=e1105]: 关闭详情
                - button "重试 detail" [ref=e1107] [cursor=pointer]:
                  - generic [ref=e1108]: 重试 detail
            - generic [ref=e1110]:
              - table [ref=e1114]:
                - rowgroup [ref=e1115]:
                  - row "jobId efd53785-7fd7-43bf-ae87-aac47392c40a" [ref=e1116]:
                    - rowheader "jobId" [ref=e1117]
                    - cell "efd53785-7fd7-43bf-ae87-aac47392c40a" [ref=e1118]:
                      - code [ref=e1121]: efd53785-7fd7-43bf-ae87-aac47392c40a
                  - row "originalFilename knowledge-upload.pdf" [ref=e1122]:
                    - rowheader "originalFilename" [ref=e1123]
                    - cell "knowledge-upload.pdf" [ref=e1124]
                  - row "status COMPLETED" [ref=e1125]:
                    - rowheader "status" [ref=e1126]
                    - cell "COMPLETED" [ref=e1127]:
                      - generic [ref=e1129]: COMPLETED
                  - row "totalChunks 1" [ref=e1130]:
                    - rowheader "totalChunks" [ref=e1131]
                    - cell "1" [ref=e1132]
                  - row "createdAt 4/25/2026, 3:14:11 AM" [ref=e1133]:
                    - rowheader "createdAt" [ref=e1134]
                    - cell "4/25/2026, 3:14:11 AM" [ref=e1135]
                  - row "updatedAt 4/25/2026, 3:14:20 AM" [ref=e1136]:
                    - rowheader "updatedAt" [ref=e1137]
                    - cell "4/25/2026, 3:14:20 AM" [ref=e1138]
                  - row "retryable false" [ref=e1139]:
                    - rowheader "retryable" [ref=e1140]
                    - cell "false" [ref=e1141]
              - generic [ref=e1143]:
                - generic [ref=e1146]: Error / operator notes
                - generic [ref=e1148]: 当前 job 没有 errorMessage。
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
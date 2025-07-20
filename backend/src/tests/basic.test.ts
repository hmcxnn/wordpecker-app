// 基础测试文件确保 Jest 配置正常工作
describe('Application Setup', () => {
  test('should pass basic test', () => {
    expect(true).toBe(true);
  });

  test('should have Node.js environment', () => {
    expect(process.env.NODE_ENV).toBeDefined();
  });
});
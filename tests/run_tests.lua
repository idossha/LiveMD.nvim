#!/usr/bin/env lua

-- Test runner for nvim-markdown-preview
-- Simple standalone runner that doesn't depend on busted
package.path = package.path .. ";../?.lua;../?/init.lua;./?.lua;../lua/?.lua;../lua/?/init.lua"

print("Running tests for nvim-markdown-preview...")
print("------------------------------------------")

-- Run the simple test directly
print("\nRunning simple_test.lua:")
dofile("simple_test.lua")

print("\nTests completed!")
-- FarstriderLibData~Init.lua
-- local _, FarstriderLibData = ...

local VERSION = 10002

if _G.FarstriderLibData and (_G.FarstriderLibData.VERSION or 0) >= VERSION then return end

FarstriderLibData.VERSION = VERSION
FarstriderLibData.Internal = {}
